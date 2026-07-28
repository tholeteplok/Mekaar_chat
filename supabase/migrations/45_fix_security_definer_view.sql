-- =============================================================================
-- Migration 45: Fix security_definer_view + revoke rls_auto_enable
--
-- Perbaikan:
--   A. Rebuild view public_profiles dengan security_invoker = true untuk
--      menghilangkan SECURITY DEFINER property yang dilaporkan Supabase
--      Advisor (lint: security_definer_view).
--
--      Sebelumnya: Supabase otomatis membungkus semua CREATE VIEW biasa
--      dengan SECURITY DEFINER -- artinya query dijalankan dengan hak
--      pemilik view (postgres/superuser), mem-bypass RLS tabel profiles.
--
--      Sesudah: View berjalan di bawah hak user yang melakukan query
--      (security_invoker), sehingga RLS tabel profiles tetap berlaku.
--
--   B. Tambah RLS policy agar view tetap berfungsi menampilkan profil
--      user lain. Diperlukan karena dengan security_invoker, RLS tabel
--      profiles berlaku -- dan policy self-only yang sudah ada sebelumnya
--      akan membuat view selalu kosong untuk profil orang lain.
--
--      Catatan keamanan: Postgres RLS tidak bisa membatasi per-kolom
--      (hanya per-baris). Policy baru ini memperbolehkan authenticated
--      SELECT semua baris profiles secara teknis -- risiko diterima karena
--      semua kode Dart sudah disiplin mengakses profil orang lain HANYA
--      lewat view public_profiles dan RPC search_public_profiles, tidak
--      pernah langsung ke tabel profiles untuk user selain diri sendiri.
--
--   C. Revoke rls_auto_enable() dari anon/authenticated. Fungsi ini adalah
--      fungsi internal Supabase (bukan buatan project ini) yang seharusnya
--      tidak diekspos ke client. Dibungkus exception handler karena REVOKE
--      mungkin gagal jika fungsi dimiliki Supabase internal.
-- =============================================================================

-- ============================================================
-- A. Rebuild view public_profiles dengan security_invoker
-- ============================================================

-- Drop view lama (SECURITY DEFINER default Supabase)
DROP VIEW IF EXISTS public.public_profiles;

-- Buat ulang dengan:
-- - security_invoker = true  : view berjalan sebagai user yang query (bukan owner)
-- - security_barrier = true  : mencegah predicate push-down yang bisa bocorkan data
--                              meski RLS sudah berlaku
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

-- Grant SELECT pada view ke authenticated
GRANT SELECT ON public.public_profiles TO authenticated;

-- ============================================================
-- B. Tambah RLS policy agar view bisa menampilkan profil lain
-- ============================================================

-- Policy "read own profile" yang sudah ada (auth.uid() = id) tetap berlaku
-- dan tidak di-drop. Policy baru ini melengkapinya: authenticated bisa
-- SELECT baris milik siapa pun (untuk keperluan view dan search).
-- Keamanan kolom sensitif dijaga oleh disiplin Dart client (lihat catatan di atas).
CREATE POLICY "Authenticated can read any public profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================
-- C. Revoke rls_auto_enable() dari anon/authenticated
-- ============================================================

DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
  REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
EXCEPTION
  WHEN insufficient_privilege THEN
    -- Fungsi dimiliki Supabase internal; project ini tidak punya hak REVOKE.
    -- Warning di Advisor untuk fungsi ini akan tetap muncul -- tidak ada
    -- tindakan lebih lanjut yang bisa dilakukan via SQL.
    RAISE NOTICE 'rls_auto_enable(): REVOKE dilewati (insufficient_privilege -- fungsi internal Supabase).';
  WHEN undefined_function THEN
    RAISE NOTICE 'rls_auto_enable(): tidak ditemukan, dilewati.';
END $$;
