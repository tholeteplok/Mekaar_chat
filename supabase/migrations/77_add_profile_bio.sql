-- ============================================================================
-- MEKAAR 3.0 Migration 77: Add Profile Bio Column
--
-- Menambahkan kolom bio (maks 160 karakter untuk personal/safety note) ke tabel
-- public.profiles dan merebuild view public.public_profiles agar menyertakan bio.
-- ============================================================================

-- 1. Tambah kolom bio ke tabel profiles (jika belum ada)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';

-- 2. Drop view public_profiles lama
DROP VIEW IF EXISTS public.public_profiles;

-- 3. Rebuild view public_profiles dengan kolom bio
CREATE VIEW public.public_profiles
WITH (security_invoker = true, security_barrier = true)
AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  bio,
  last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key
FROM public.profiles;

-- 4. Pastikan permission SELECT untuk authenticated users
GRANT SELECT ON public.public_profiles TO authenticated;
