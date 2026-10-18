-- ============================================================================
-- MEKAAR 3.0 Migration 89: Security Advisor Hardening Remediation
-- ============================================================================
-- 1. Mengunci search_path pada fungsi trigger (function_search_path_mutable)
-- 2. Menghapus policy broad SELECT pada storage.objects untuk public bucket
--    (public_bucket_allows_listing) tanpa mengganggu public URL media
-- 3. Mencabut hak akses role PUBLIC & anon pada fungsi SECURITY DEFINER sensitif
--    (anon_security_definer_function_executable)
-- 4. Mengunci fungsi cron internal / trigger sistem agar hanya dapat dipanggil
--    oleh service_role (authenticated_security_definer_function_executable hardening)
-- ============================================================================

BEGIN;

-- ============================================================================
-- BAGIAN 1: Perbaikan Search Path (function_search_path_mutable)
-- ============================================================================

-- 1.1. Trigger set_forwarding_protection_updated_at
CREATE OR REPLACE FUNCTION public.set_forwarding_protection_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.forwarding_protection_enabled IS DISTINCT FROM OLD.forwarding_protection_enabled THEN
    NEW.forwarding_protection_updated_at = now();
  ELSE
    NEW.forwarding_protection_updated_at = OLD.forwarding_protection_updated_at;
  END IF;
  RETURN NEW;
END;
$$;

-- 1.2. Trigger fn_auto_expire_trip_permissions
CREATE OR REPLACE FUNCTION public.fn_auto_expire_trip_permissions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'active' AND NEW.end_time < NOW() THEN
    NEW.status := 'completed';
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- BAGIAN 2: Proteksi Enumerasi Storage Objects (public_bucket_allows_listing)
-- ============================================================================
-- Catatan: Bucket 'avatars' dan 'emoji-packs' berstatus public = true.
-- File media dapat diakses langsung oleh klien via URL publik (/storage/v1/object/public/...)
-- Policy SELECT broad pada storage.objects membuka celah enumerasi/listing seluruh direktori file.

DROP POLICY IF EXISTS "Allow public avatar select" ON storage.objects;
DROP POLICY IF EXISTS "emoji packs read for authenticated" ON storage.objects;

-- ============================================================================
-- BAGIAN 3: Penguatan Proteksi RPC Admin (Anti-Spoofing & Role Revocation)
-- ============================================================================

-- 3.1. admin_set_legal_hold
CREATE OR REPLACE FUNCTION public.admin_set_legal_hold(
  p_target_user_id uuid,
  p_active boolean,
  p_case_ref text DEFAULT NULL,
  p_admin_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
  v_action text;
BEGIN
  -- Anti-spoofing: jika dipanggil via JWT authenticated, gunakan auth.uid()
  v_admin_id := COALESCE(auth.uid(), p_admin_id);

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Pengguna tidak terautentikasi.';
  END IF;

  -- IMPERATIVE GUARD: Verifikasi Role Admin
  SELECT is_admin INTO v_is_admin
  FROM public.profiles
  WHERE id = v_admin_id;

  IF COALESCE(v_is_admin, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'FORBIDDEN: Hanya administrator terautentikasi yang dapat mengatur status Legal Hold.';
  END IF;

  -- Update status legal hold pada profiles
  UPDATE public.profiles
  SET legal_hold_active = p_active,
      legal_hold_case_ref = CASE WHEN p_active THEN p_case_ref ELSE NULL END
  WHERE id = p_target_user_id;

  v_action := CASE WHEN p_active THEN 'ENABLE_LEGAL_HOLD' ELSE 'DISABLE_LEGAL_HOLD' END;

  -- Catat aksi ke admin_audit_logs (Immutable)
  INSERT INTO public.admin_audit_logs (
    admin_id,
    action_type,
    target_user_id,
    reason,
    metadata
  ) VALUES (
    v_admin_id,
    v_action,
    p_target_user_id,
    COALESCE(p_case_ref, 'Status Legal Hold diubah oleh administrator'),
    jsonb_build_object('legal_hold_active', p_active, 'case_ref', p_case_ref)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_set_legal_hold(uuid, boolean, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_legal_hold(uuid, boolean, text, uuid) TO authenticated, service_role;

-- 3.2. admin_suspend_user
CREATE OR REPLACE FUNCTION public.admin_suspend_user(
  p_target_user_id uuid,
  p_reason text,
  p_admin_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
BEGIN
  -- Anti-spoofing: jika dipanggil via JWT authenticated, gunakan auth.uid()
  v_admin_id := COALESCE(auth.uid(), p_admin_id);

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Pengguna tidak terautentikasi.';
  END IF;

  -- IMPERATIVE GUARD 1: Verifikasi Role Admin
  SELECT is_admin INTO v_is_admin
  FROM public.profiles
  WHERE id = v_admin_id;

  IF COALESCE(v_is_admin, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'FORBIDDEN: Hanya administrator terautentikasi yang dapat membekukan akun.';
  END IF;

  -- IMPERATIVE GUARD 2: Cek Imunitas Sesi SOS Aktif Korban
  IF EXISTS (
    SELECT 1 FROM public.sos_sessions
    WHERE user_id = p_target_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'SUSPEND_BLOCKED: Pengguna target sedang dalam Sesi Darurat SOS Aktif. Tindakan pembekuan diblokir demi keselamatan jiwa.';
  END IF;

  -- Update status suspensi pada profiles
  UPDATE public.profiles
  SET is_suspended = true,
      suspended_at = NOW(),
      suspension_reason = p_reason
  WHERE id = p_target_user_id;

  -- Catat aksi ke admin_audit_logs
  INSERT INTO public.admin_audit_logs (
    admin_id,
    action_type,
    target_user_id,
    reason
  ) VALUES (
    v_admin_id,
    'SUSPEND',
    p_target_user_id,
    p_reason
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_suspend_user(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user(uuid, text, uuid) TO authenticated, service_role;

-- ============================================================================
-- BAGIAN 4: Penguncian Fungsi Cron Internal & Trigger Sistem (service_role Only)
-- ============================================================================

-- 4.1. check_active_guardian_expiry
REVOKE ALL ON FUNCTION public.check_active_guardian_expiry() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_active_guardian_expiry() TO service_role;

-- 4.2. check_call_update_immutability
REVOKE ALL ON FUNCTION public.check_call_update_immutability() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_call_update_immutability() TO service_role;

-- 4.3. expire_old_guardian_invites
REVOKE ALL ON FUNCTION public.expire_old_guardian_invites() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_old_guardian_invites() TO service_role;

-- 4.4. purge_expired_messages
REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO service_role;

-- ============================================================================
-- BAGIAN 5: Pencabutan Hak Akses Anonim pada Seluruh Fungsi Pengguna
-- ============================================================================

-- 5.1. Manajemen Perangkat
REVOKE ALL ON FUNCTION public.cleanup_my_duplicate_devices() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_my_duplicate_devices() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.clear_device_fcm_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_device_fcm_token(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.clear_fcm_token() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_fcm_token() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.register_device(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_device(text, text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.revoke_device(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_device(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.list_my_devices() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_my_devices() TO authenticated, service_role;

-- 5.2. Manipulasi Obrolan & Room
REVOKE ALL ON FUNCTION public.execute_room_burn_on_exit(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_room_burn_on_exit(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.execute_room_scheduled_wipe(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_room_scheduled_wipe(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.hide_all_room_messages(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hide_all_room_messages(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_room_burn_on_exit(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_burn_on_exit(uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_room_disappearing_hours(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_disappearing_hours(uuid, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_room_scheduled_wipe(uuid, time without time zone, character varying, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_scheduled_wipe(uuid, time without time zone, character varying, timestamp with time zone) TO authenticated, service_role;

-- 5.3. Interaksi Fitur & Keamanan
REVOKE ALL ON FUNCTION public.get_nearby_friends(double precision, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_friends(double precision, double precision) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_call_authorized(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_call_authorized(uuid, uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_user_active() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_user_active() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_view_once_opened(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_view_once_opened(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text, uuid, uuid, text) TO authenticated, service_role;

COMMIT;
