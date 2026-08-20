-- 69_verify_push_config.sql
-- Verifikasi konfigurasi push notification saat migration dijalankan.
--
-- Latar belakang: di Supabase HOSTED, role `postgres` BUKAN superuser, sehingga
-- `ALTER DATABASE postgres SET app.settings.push_webhook_url` gagal dengan
-- 42501 "permission denied to set parameter". Pendekatan GUC hanya jalan di
-- local dev (CLI) tempat postgres benar-benar superuser.
--
-- Solusi: konfigurasi disimpan di tabel `public.app_config` (key-value).
-- Migration 70 mengganti notify_push_webhook() agar membaca dari tabel ini
-- (dengan fallback GUC untuk local dev).
--
-- Migration ini HANYA membuat tabel. Verifikasi dipindah ke migration 71
-- (terpisah dari transaksi pembuatan tabel, agar CREATE TABLE tidak ikut
-- rollback saat verifikasi gagal).

BEGIN;

-- ── Tabel konfigurasi push ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- Izinkan akses baca untuk semua role yang menjalankan trigger
-- (trigger jalan sebagai user session, mis. authenticator/postgres).
GRANT SELECT ON TABLE public.app_config TO authenticated, anon, service_role;

COMMIT;