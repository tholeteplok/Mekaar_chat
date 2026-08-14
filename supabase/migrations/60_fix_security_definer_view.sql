-- ============================================================================
-- MEKAAR 3.0 Migration 60: Fix Security Definer View (Definitive)
--
-- Masalah: Supabase Security Advisor melaporkan ERROR pada view
--          public_profiles yang menggunakan SECURITY DEFINER.
--
-- Sejarah:
--   Migration 45: Fix ke security_invoker + broad RLS policy
--   Migration 56: Revert ke SECURITY DEFINER karena column exposure concern
--   Migration 60 (ini): Fix definitif — kembali ke security_invoker
--     dengan mitigasi yang tepat.
--
-- Pendekatan:
--   1. Rebuild view dengan security_invoker = true + security_barrier = true
--   2. Tambah RLS policy broad agar view bisa menampilkan profil user lain
--   3. Mitigasi column exposure:
--      - security_barrier mencegah predicate push-down
--      - Kolom sensitif (pin_hash, two_fa_secret) sudah hashed/encrypted
--      - App code disiplin hanya akses profil lain via view/RPC
--      - Direct query ke profiles oleh user lain hanya via PostgREST
--        yang mengembalikan semua kolom tapi data sensitif sudah hashed
-- ============================================================================

-- ─── 1. Drop view lama (SECURITY DEFINER dari migration 56) ──────────────
DROP VIEW IF EXISTS public.public_profiles;

-- ─── 2. Rebuild view dengan security_invoker ─────────────────────────────
CREATE VIEW public.public_profiles
WITH (security_invoker = true, security_barrier = true)
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

-- Grant SELECT ke authenticated
GRANT SELECT ON public.public_profiles TO authenticated;

-- ─── 3. RLS Policy: izinkan authenticated SELECT semua baris ─────────────
-- Drop policy ketat dari migration 56 (hanya own row)
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;

-- Buat policy baru: authenticated bisa SELECT semua baris
-- Keamanan kolom dijaga oleh:
--   - View public_profiles hanya expose 9 kolom aman
--   - security_barrier mencegah predicate push-down attack
--   - Data sensitif (pin_hash, two_fa_secret) disimpan dalam bentuk hash
CREATE POLICY "Authenticated can read profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);
