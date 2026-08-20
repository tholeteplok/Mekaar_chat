-- 71_verify_push_config.sql
-- Verifikasi konfigurasi push notification di tabel public.app_config.
--
-- Migration ini sengaja dibuat TERPISAH dari migration 69 (yang membuat tabel)
-- supaya CREATE TABLE tidak ikut rollback ketika verifikasi gagal. Urutan push:
--
--   1. push #1 → 69 (tabel) ✓, 70 (fungsi) ✓, 71 (verifikasi) ✗ → berhenti.
--   2. Seed config di SQL Editor:
--        INSERT INTO public.app_config (key, value) VALUES
--          ('push_webhook_url', 'https://<project-ref>.supabase.co/functions/v1/send-push-notification'),
--          ('anon_key', '<anon-key>')
--          ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
--   3. push #2 → 71 (verifikasi) ✓.

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