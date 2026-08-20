-- 69_verify_push_config.sql
-- Verifikasi konfigurasi push notification saat migration dijalankan.
--
-- Latar belakang: notify_push_webhook() (migration 39) membaca GUC
-- `app.settings.push_webhook_url` dan `app.settings.anon_key`. Keduanya BUKAN
-- bagian migration — harus di-set manual sekali lewat SQL Editor. Kalau belum
-- di-set, trigger berjalan tanpa error (hanya RAISE WARNING) dan push tidak
-- pernah terkirim sama sekali untuk message/call/SOS.
--
-- Migration ini mengubah kegagalan silent menjadi loud-fail: RAISE EXCEPTION
-- kalau setting belum ada, sehingga kelewat konfigurasi langsung ketahuan di
-- deploy time, bukan setelah user komplain "notif gak muncul".

BEGIN;

DO $$
DECLARE
  webhook_url text;
  anon_key text;
  msg text;
BEGIN
  webhook_url := current_setting('app.settings.push_webhook_url', true);

  IF webhook_url IS NULL OR webhook_url = '' THEN
    msg := 'app.settings.push_webhook_url belum dikonfigurasi. Jalankan dulu di SQL Editor:'
      || E'\n'
      || '  ALTER DATABASE postgres SET app.settings.push_webhook_url = ''https://<project-ref>.supabase.co/functions/v1/send-push-notification'';'
      || E'\n'
      || 'Setelah itu jalankan ulang migration ini.';
    -- Format string RAISE harus literal; pesan ekspresi dilewatkan sebagai argumen.
    RAISE EXCEPTION '%', msg;
  END IF;

  anon_key := current_setting('app.settings.anon_key', true);
  IF anon_key IS NULL OR anon_key = '' THEN
    msg := 'app.settings.anon_key belum dikonfigurasi. Direkomendasikan:'
      || E'\n'
      || '  ALTER DATABASE postgres SET app.settings.anon_key = ''<anon-key>'';'
      || E'\n'
      || '(tidak memblokir, karena Edge Function memakai service role saat dipanggil dari pg_net).';
    RAISE WARNING '%', msg;
  END IF;

  RAISE NOTICE 'Push config OK: app.settings.push_webhook_url = %', webhook_url;
END $$;

COMMIT;