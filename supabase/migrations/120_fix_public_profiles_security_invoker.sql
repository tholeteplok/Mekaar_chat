-- ==============================================================================
-- 120_fix_public_profiles_security_invoker.sql
-- Memulihkan pembacaan profil publik lawan bicara, anggota grup, kontak, & Guardian
-- pasca regresi security_invoker = true pada migrasi 117.
--
-- Akar Masalah:
-- - Tabel dasar public.profiles dikunci oleh RLS ketat `USING (auth.uid() = id)`
--   (Migrasi 90 & 103) untuk melindungi kolom rahasia (pin_hash, two_fa_secret,
--   e2ee_key_backup, email).
-- - Migrasi 117 menambahkan `security_invoker = true` pada view public.public_profiles,
--   sehingga kueri klien ke public_profiles ikut terblokir RLS `auth.uid() = id`
--   untuk semua pengguna selain diri sendiri (menyebabkan fallback 'Saved Messages',
--   'User', 'Anggota', kontak kosong, dan gagal baca kunci publik E2EE lawan).
--
-- Solusi:
-- 1. Kembalikan public.public_profiles ke `security_invoker = false` dengan
--    `security_barrier = true` (proyeksi khusus 12 kolom publik aman).
-- 2. Kunci ketat GRANT hanya untuk `authenticated` dan `service_role` (push notif),
--    serta REVOKE penuh dari `anon` dan `PUBLIC`.
-- 3. Pastikan public.user_contacts_view tetap `security_invoker = true` agar
--    daftar kontak & vault tetap tunduk pada RLS `user_contacts` (`user_id = auth.uid()`).
-- ==============================================================================

-- 1. Kembalikan atribut security_invoker = false pada public.public_profiles secara atomik
ALTER VIEW public.public_profiles
  SET (security_invoker = false, security_barrier = true);

-- 2. Kunci ketat hak akses view public.public_profiles
REVOKE ALL ON public.public_profiles FROM anon, PUBLIC;
GRANT SELECT ON public.public_profiles TO authenticated, service_role;

-- 3. Pastikan public.user_contacts_view tetap menggunakan security_invoker = true
ALTER VIEW public.user_contacts_view
  SET (security_invoker = true, security_barrier = true);

REVOKE ALL ON public.user_contacts_view FROM anon, PUBLIC;
GRANT SELECT ON public.user_contacts_view TO authenticated;
