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
-- Kalau tabel ini kosong, migration gagal loud (RAISE EXCEPTION) dengan
-- instruksi INSERT, bukan silent-fail seperti dulu.

BEGIN;

-- ── Tabel konfigurasi push ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- Izinkan akses baca untuk semua role yang menjalankan trigger
-- (trigger jalan sebagai user session, mis. authenticator/postgres).
GRANT SELECT ON TABLE public.app_config TO authenticated, anon, service_role;

-- ── Verifikasi konfigurasi ────────────────────────────────────────────────
DO $$
DECLARE
  webhook_url text;
  msg text;
BEGIN
  SELECT value INTO webhook_url FROM public.app_config WHERE key = 'push_webhook_url';

  IF webhook_url IS NULL OR webhook_url = '' THEN
    msg := 'app_config.push_webhook_url belum diisi. Jalankan dulu di SQL Editor:'
      || E'\n'
      || '  INSERT INTO public.app_config (key, value) VALUES'
      || E'\n'
      || '    (''push_webhook_url'', ''https://<project-ref>.supabase.co/functions/v1/send-push-notification''),'
      || E'\n'
      || '    (''anon_key'', ''<anon-key-dari-Dashboard→Settings→API>'')'
      || E'\n'
      || '    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;'
      || E'\n'
      || 'Setelah itu jalankan ulang migration ini.';
    RAISE EXCEPTION '%', msg;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.app_config WHERE key = 'anon_key') THEN
    msg := 'app_config.anon_key belum diisi. Direkomendasikan:'
      || E'\n'
      || '  INSERT INTO public.app_config (key, value) VALUES (''anon_key'', ''<anon-key-dari-Dashboard→Settings→API>'')'
      || E'\n'
      || '    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;'
      || E'\n'
      || '(tidak memblokir, karena Edge Function memakai service role saat dipanggil dari pg_net).';
    RAISE WARNING '%', msg;
  END IF;

  RAISE NOTICE 'Push config OK: push_webhook_url = %', webhook_url;
END $$;

COMMIT;