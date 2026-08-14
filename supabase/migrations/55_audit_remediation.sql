-- ============================================================================
-- MEKAAR 3.0 Migration 55: Audit Remediation & Security Hardening
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DB-3 & DB-1: Admin Role & Profiles RLS Hardening
-- ----------------------------------------------------------------------------

-- Tambahkan kolom is_admin jika belum ada
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Drop policy longgar dari migration 45 yang membiarkan SELECT seluruh kolom profiles
DROP POLICY IF EXISTS "Authenticated can read any public profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles public read" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can read active user profiles" ON public.profiles;

-- Policy 1: Pembacaan kolom profil untuk pengguna terautentikasi
CREATE POLICY "Authenticated users can read active user profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IS NOT NULL
  );

-- Policy 2: User hanya bisa meng-UPDATE profil miliknya sendiri
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- 2. DB-2 & DB-6: Fix submit_user_report RPC (Rate Limit Parameter & Revoke)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_user_report(uuid, text, text, uuid, uuid, text) CASCADE;

CREATE OR REPLACE FUNCTION public.submit_user_report(
  p_reported_user_id uuid,
  p_category text,
  p_reason text,
  p_room_id uuid DEFAULT NULL,
  p_message_id uuid DEFAULT NULL,
  p_evidence_snapshot text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_report_id uuid;
  v_caller text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_caller := auth.uid()::text;

  -- Rate limiting: Gunakan signature benar dari check_rate_limit(p_caller, p_type, p_max_attempts, p_interval)
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_rate_limit') THEN
    PERFORM public.check_rate_limit(
      v_caller,
      'submit_report',
      5,
      interval '1 hour'
    );
  END IF;

  -- Verifikasi message_id jika dilampirkan
  IF p_message_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.messages
      WHERE id = p_message_id AND sender_id = p_reported_user_id
    ) THEN
      RAISE EXCEPTION 'INVALID_EVIDENCE: Pesan yang dilaporkan tidak valid atau tidak cocok dengan pengirim.';
    END IF;
  END IF;

  INSERT INTO public.user_reports (
    reporter_id,
    reported_user_id,
    room_id,
    message_id,
    category,
    reason,
    evidence_snapshot
  ) VALUES (
    auth.uid(),
    p_reported_user_id,
    p_room_id,
    p_message_id,
    p_category,
    p_reason,
    p_evidence_snapshot
  ) RETURNING id INTO v_report_id;

  RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text, uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text, uuid, uuid, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. DB-3 & DB-6: Fix admin_suspend_user RPC (Admin Guard & Revoke)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_suspend_user(uuid, text, uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.admin_suspend_user(
  p_target_user_id uuid,
  p_reason text,
  p_admin_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
BEGIN
  v_admin_id := COALESCE(p_admin_id, auth.uid());

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.admin_suspend_user(uuid, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user(uuid, text, uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. DB-4: Fix mark_view_once_opened RPC (Auth Check & Recipient Guard)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.mark_view_once_opened(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.mark_view_once_opened(target_message_id uuid)
RETURNS void AS $$
DECLARE
  v_room_id uuid;
  v_sender_id uuid;
  v_is_recipient boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Dapatkan room_id dan sender_id pesan
  SELECT room_id, sender_id INTO v_room_id, v_sender_id
  FROM public.messages
  WHERE id = target_message_id AND is_view_once = true;

  IF v_room_id IS NULL THEN
    RAISE EXCEPTION 'Pesan view-once tidak ditemukan';
  END IF;

  -- Pastikan pemanggil BUKAN pengirim pesan (harus penerima di room)
  IF auth.uid() = v_sender_id THEN
    RAISE EXCEPTION 'Pengirim tidak dapat membuka pesan view-once sendiri';
  END IF;

  -- Pastikan pemanggil adalah anggota room
  SELECT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = v_room_id AND user_id = auth.uid()
  ) INTO v_is_recipient;

  IF NOT v_is_recipient THEN
    RAISE EXCEPTION 'FORBIDDEN: Anda bukan anggota room ini';
  END IF;

  UPDATE public.messages
  SET view_once_opened = true,
      view_once_opened_at = NOW()
  WHERE id = target_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.mark_view_once_opened(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_view_once_opened(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. DB-5: Fix Storage Avatars RLS (Prevent Public Enumeration)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public avatar select" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read avatars" ON storage.objects;

CREATE POLICY "Authenticated users can read avatars"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'avatars');

-- ----------------------------------------------------------------------------
-- 6. DB-8: Fix expire_old_guardian_invites (SET search_path)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.expire_old_guardian_invites() CASCADE;

CREATE OR REPLACE FUNCTION public.expire_old_guardian_invites()
RETURNS trigger AS $$
BEGIN
  UPDATE public.guardians
  SET status = 'expired'
  WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '7 days';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ----------------------------------------------------------------------------
-- 7. DB-9, DB-10: Indexes Optimization
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_guardians_status_created
  ON public.guardians (status, created_at);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter
  ON public.user_reports (reporter_id);

CREATE INDEX IF NOT EXISTS idx_user_reports_reported
  ON public.user_reports (reported_user_id);

CREATE INDEX IF NOT EXISTS idx_user_reports_status
  ON public.user_reports (status);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin
  ON public.admin_audit_logs (admin_id);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
  ON public.admin_audit_logs (target_user_id);

-- ----------------------------------------------------------------------------
-- 8. DB-11 & DB-12: RLS Policies for user_reports & admin_audit_logs
-- ----------------------------------------------------------------------------
-- Admin UPDATE Policy untuk user_reports
DROP POLICY IF EXISTS user_reports_admin_update ON public.user_reports;
CREATE POLICY user_reports_admin_update ON public.user_reports
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Admin SELECT Policy untuk admin_audit_logs
DROP POLICY IF EXISTS admin_audit_logs_admin_select ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_admin_select ON public.admin_audit_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ----------------------------------------------------------------------------
-- 9. DB-13: Trigger Generic Auto-Update updated_at
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.trigger_set_timestamp() CASCADE;

CREATE OR REPLACE FUNCTION public.trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS set_user_reports_timestamp ON public.user_reports;
CREATE TRIGGER set_user_reports_timestamp
  BEFORE UPDATE ON public.user_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_set_timestamp();

-- ----------------------------------------------------------------------------
-- 10. DB-14: Clean Up Orphaned Table call_logs
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.call_logs CASCADE;

-- ----------------------------------------------------------------------------
-- 11. G-4: Server-Side Active Guardian Expiry Guard
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.check_active_guardian_expiry() CASCADE;

CREATE OR REPLACE FUNCTION public.check_active_guardian_expiry()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'active' AND NEW.expires_at IS NOT NULL AND NEW.expires_at < NOW() THEN
    NEW.status = 'expired';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_active_guardian_expiry ON public.guardians;
CREATE TRIGGER trigger_active_guardian_expiry
  BEFORE INSERT OR UPDATE ON public.guardians
  FOR EACH ROW
  EXECUTE FUNCTION public.check_active_guardian_expiry();
