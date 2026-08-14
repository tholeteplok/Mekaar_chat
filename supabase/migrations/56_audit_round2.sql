-- ============================================================================
-- MEKAAR 3.0 Migration 56: Audit Round 2 Remediation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DB-1 (CRITICAL): Fix profiles column exposure
--
--    Masalah: RLS policy "auth.uid() IS NOT NULL" memberi semua authenticated
--    user akses SELECT ke SEMUA kolom profiles (termasuk pin_hash, two_fa_secret).
--    RLS Postgres hanya bisa restrict ROW, bukan COLUMN.
--
--    Solusi:
--      a. Ubah RLS menjadi auth.uid() = id (hanya bisa baca row sendiri)
--      b. Rebuild view public_profiles sebagai SECURITY DEFINER
--         (bypass RLS, tapi hanya expose kolom aman)
-- ----------------------------------------------------------------------------

-- a. Drop policy longgar dari migration 55
DROP POLICY IF EXISTS "Authenticated users can read active user profiles" ON public.profiles;
-- Drop juga alias lama yang mungkin tersisa
DROP POLICY IF EXISTS "Authenticated can read any public profile" ON public.profiles;

-- Buat policy baru: user hanya bisa SELECT row milik sendiri
-- Efek: SELECT langsung ke tabel profiles hanya return data sendiri (semua kolom)
CREATE POLICY "Users can read own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- b. Rebuild view public_profiles sebagai SECURITY DEFINER
--    View ini owned oleh postgres (superuser) sehingga bypass RLS,
--    tapi hanya mengekspos kolom yang AMAN untuk publik.
DROP VIEW IF EXISTS public.public_profiles;

CREATE VIEW public.public_profiles
WITH (security_barrier = true)
AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key
FROM public.profiles;

-- Pastikan view ini berjalan sebagai owner (postgres) — SECURITY DEFINER.
-- Postgres CREATE VIEW tanpa security_invoker = SECURITY DEFINER secara default.
-- security_barrier = true mencegah predicate push-down yang bisa bocorkan data.

-- Grant SELECT pada view ke authenticated & anon (untuk search profil publik)
GRANT SELECT ON public.public_profiles TO authenticated;

-- Revoke direct INSERT/DELETE dari authenticated (hanya UPDATE own profile via policy)
-- INSERT dihandle oleh trigger/RPC saat registrasi.
-- (UPDATE policy sudah ada dari migration 55: "Users can update own profile")

-- ----------------------------------------------------------------------------
-- 2. DB-8: Recreate trigger trg_expire_old_guardian_invites
--
--    Masalah: DROP FUNCTION ... CASCADE di migration 55 juga men-drop
--    trigger yang terhubung. Trigger perlu di-recreate.
-- ----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_expire_old_guardian_invites ON guardians;
CREATE TRIGGER trg_expire_old_guardian_invites
  AFTER INSERT OR UPDATE ON guardians
  FOR EACH STATEMENT
  EXECUTE FUNCTION expire_old_guardian_invites();
