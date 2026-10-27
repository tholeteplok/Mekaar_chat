-- ============================================================================
-- MEKAAR 3.0 Migration 107: Lock Permanent Username & Revoke Change RPC
-- Menerapkan penguncian permanen pada kolom username di tabel profiles.
-- Pengguna hanya dapat mengisi username sekali (misal: saat onboarding).
-- Setelah diatur, username tidak dapat diubah lagi.
-- ============================================================================

-- 1. Buat fungsi trigger guard untuk mencegah perubahan username yang sudah ada
CREATE OR REPLACE FUNCTION public.guard_permanent_username()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Izinkan operasi internal service_role / superuser jika diperlukan untuk maintenance
  IF auth.role() = 'service_role' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;

  -- Jika username sebelumnya sudah diisi dan nilai baru berbeda dari nilai lama, tolak perubahan!
  IF OLD.username IS NOT NULL 
     AND trim(OLD.username) <> '' 
     AND NEW.username IS DISTINCT FROM OLD.username THEN
    RAISE EXCEPTION 'Akses ditolak: Username bersifat permanen dan tidak dapat diubah setelah diatur.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- 2. Pasang trigger BEFORE UPDATE pada tabel profiles
DROP TRIGGER IF EXISTS trg_guard_permanent_username ON public.profiles;

CREATE TRIGGER trg_guard_permanent_username
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_permanent_username();

-- 3. Cabut hak dan hapus RPC change_username (mekanisme cooldown 60 hari lama)
REVOKE EXECUTE ON FUNCTION public.change_username(TEXT) FROM authenticated, anon, PUBLIC;
DROP FUNCTION IF EXISTS public.change_username(TEXT);
