-- 69_app_config_table.sql
-- Tabel konfigurasi key-value untuk menyimpan parameter runtime server-side
-- (seperti push_webhook_url dan anon_key) di Supabase Hosted environment.
--
-- Latar belakang: di Supabase HOSTED, role `postgres` BUKAN superuser, sehingga
-- `ALTER DATABASE postgres SET app.settings.push_webhook_url` gagal dengan
-- 42501 "permission denied to set parameter".
--
-- Solusi: konfigurasi disimpan di tabel `public.app_config` (key-value).
-- Migration 70 memperbarui notify_push_webhook() agar membaca dari tabel ini.

BEGIN;

-- 1. Buat tabel konfigurasi internal
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- 2. Security Hardening: Aktifkan RLS agar aman dari akses REST publik
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 3. Cabut hak akses dari pengguna publik/klien biasa
REVOKE ALL ON TABLE public.app_config FROM anon, authenticated;

-- 4. Izinkan akses hanya untuk backend / service_role
GRANT ALL ON TABLE public.app_config TO service_role;

DROP POLICY IF EXISTS app_config_service_role_access ON public.app_config;
CREATE POLICY app_config_service_role_access ON public.app_config
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

COMMIT;