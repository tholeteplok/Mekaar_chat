-- ============================================================================
-- MEKAAR 3.0 Migration 103: Tier 0 Hotfix Keamanan Backend
-- Remediasi C1, H2, H3, dan M1 (Defense-in-Depth & Privileged Column Protection)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. REMEDIASI C1: Pengamanan Kolom Hak Istimewa pada Tabel profiles
-- ----------------------------------------------------------------------------

-- A. Trigger Guard BEFORE UPDATE: Menolak pengubahan kolom istimewa oleh pengguna biasa
CREATE OR REPLACE FUNCTION public.guard_profiles_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text := auth.role();
BEGIN
  -- Izinkan service_role atau superuser/migrasi database melakukan perubahan
  IF v_role = 'service_role' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;

  -- 1) Blokir perubahan flag admin
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'Akses ditolak: Kolom is_admin hanya dapat diubah oleh administrator sistem.'
      USING ERRCODE = '42501';
  END IF;

  -- 2) Blokir perubahan status suspensi dan alasannya
  IF NEW.is_suspended IS DISTINCT FROM OLD.is_suspended
     OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
     OR NEW.suspended_reason IS DISTINCT FROM OLD.suspended_reason THEN
    RAISE EXCEPTION 'Akses ditolak: Kolom is_suspended dan status sanksi hanya dapat diubah oleh administrator.'
      USING ERRCODE = '42501';
  END IF;

  -- 3) Blokir perubahan status legal hold
  IF NEW.legal_hold IS DISTINCT FROM OLD.legal_hold
     OR NEW.legal_hold_at IS DISTINCT FROM OLD.legal_hold_at
     OR NEW.legal_hold_reason IS DISTINCT FROM OLD.legal_hold_reason
     OR NEW.legal_hold_by IS DISTINCT FROM OLD.legal_hold_by THEN
    RAISE EXCEPTION 'Akses ditolak: Status legal_hold tidak dapat dimodifikasi oleh pengguna biasa.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profiles_privileged_columns ON public.profiles;
CREATE TRIGGER trg_guard_profiles_privileged_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_profiles_privileged_columns();

-- B. Column-Level Grant Restrictions (Lapis Pertahanan Hak Akses Kolom)
REVOKE UPDATE ON public.profiles FROM authenticated, anon;

GRANT UPDATE (
  display_name,
  full_name,
  avatar_url,
  bio,
  last_seen_privacy,
  chat_invitation_mode,
  fcm_token,
  fcm_token_updated_at,
  is_device_lost,
  lock_screen_message,
  recovery_contact,
  username,
  e2ee_public_key,
  e2ee_key_backup,
  pin_hash,
  duress_pin_hash,
  duress_enabled
) ON public.profiles TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. REMEDIASI M1: Pengamanan Kolom Peran pada room_participants
-- ----------------------------------------------------------------------------

-- A. Trigger Guard BEFORE UPDATE: Menolak pengubahan role atau metadata peserta oleh anggota biasa
CREATE OR REPLACE FUNCTION public.guard_room_participants_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text := auth.role();
  v_is_owner boolean := false;
BEGIN
  IF v_role = 'service_role' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;

  -- Jika role, invited_by, profile_id, atau room_id mencoba diubah
  IF NEW.role IS DISTINCT FROM OLD.role
     OR NEW.invited_by IS DISTINCT FROM OLD.invited_by
     OR NEW.profile_id IS DISTINCT FROM OLD.profile_id
     OR NEW.room_id IS DISTINCT FROM OLD.room_id THEN

    -- Periksa apakah pemanggil adalah owner dari room bersangkutan
    SELECT EXISTS (
      SELECT 1 FROM public.room_participants
      WHERE room_id = OLD.room_id
        AND profile_id = auth.uid()
        AND role = 'owner'
    ) INTO v_is_owner;

    IF NOT v_is_owner THEN
      RAISE EXCEPTION 'Akses ditolak: Peran (role) partisipan obrolan hanya dapat diubah oleh pemilik (owner) grup.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_room_participants_role_escalation ON public.room_participants;
CREATE TRIGGER trg_guard_room_participants_role_escalation
  BEFORE UPDATE ON public.room_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_room_participants_role_escalation();

-- B. Column-Level Grant Restrictions pada room_participants
REVOKE UPDATE ON public.room_participants FROM authenticated, anon;

GRANT UPDATE (
  is_muted,
  muted_until,
  last_read_at,
  history_cleared_at,
  deleted_at
) ON public.room_participants TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. REMEDIASI H2: Menutup Dump Direktori public_profiles dari Peran anon
-- ----------------------------------------------------------------------------

-- A. Cabut izin akses langsung view public_profiles dari anon
REVOKE ALL ON public.public_profiles FROM anon;

-- B. Perbarui view public_profiles dengan penghormatan privasi last_seen_at di layer database
CREATE OR REPLACE VIEW public.public_profiles
WITH (security_barrier = true)
AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  CASE
    WHEN last_seen_privacy = 'nobody' THEN NULL::TIMESTAMPTZ
    ELSE last_seen_at
  END AS last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key,
  chat_invitation_mode,
  bio
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;
REVOKE SELECT ON public.public_profiles FROM anon;

-- C. Tambahkan RPC aman untuk memeriksa ketersediaan username saat pendaftaran tanpa membocorkan data profil
CREATE OR REPLACE FUNCTION public.is_username_available(p_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_taken boolean;
BEGIN
  IF p_username IS NULL OR trim(p_username) = '' THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE lower(username) = lower(trim(p_username))
  ) INTO v_taken;

  RETURN NOT v_taken;
END;
$$;

REVOKE ALL ON FUNCTION public.is_username_available(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_username_available(text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. REMEDIASI H3: Cabut Hak Eksekusi resolve_login_email dari anon
-- ----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.resolve_login_email(TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO authenticated, service_role;
