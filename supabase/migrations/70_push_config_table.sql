-- 70_push_config_table.sql
-- Ganti sumber konfigurasi push dari GUC (`app.settings.*`) ke tabel
-- `public.app_config`.
--
-- Kenapa: di Supabase hosted, `ALTER DATABASE postgres SET app.settings.*`
-- gagal dengan 42501 (postgres bukan superuser). GUC hanya bisa di-set per
-- session — tidak akan terlihat oleh session lain tempat trigger berjalan.
--
-- Fungsi ini tetap fallback ke GUC jika baris tabel tidak ada, supaya local
-- dev (supabase CLI, postgres = superuser) tetap berfungsi.

CREATE OR REPLACE FUNCTION public.notify_push_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  webhook_url text;
  anon_key text;
  payload jsonb;
  request_id bigint;
BEGIN
  -- 1) Konfigurasi utama dari tabel app_config (produksi).
  SELECT value INTO webhook_url FROM public.app_config WHERE key = 'push_webhook_url';

  -- 2) Fallback GUC (local dev CLI).
  IF webhook_url IS NULL OR webhook_url = '' THEN
    webhook_url := current_setting('app.settings.push_webhook_url', true);
  END IF;

  -- 3) Fallback terakhir dari supabase_url (dev).
  IF webhook_url IS NULL OR webhook_url = '' THEN
    webhook_url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-push-notification';
  END IF;

  -- Skip jika URL masih kosong (belum dikonfigurasi)
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE WARNING 'push_webhook_url belum dikonfigurasi, skip push notification';
    RETURN NEW;
  END IF;

  -- anon_key untuk header apikey (opsional, Edge Function pakai service role).
  SELECT value INTO anon_key FROM public.app_config WHERE key = 'anon_key';
  IF anon_key IS NULL OR anon_key = '' THEN
    anon_key := current_setting('app.settings.anon_key', true);
  END IF;

  -- Bangun payload sesuai format pg_net webhook
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  -- Kirim HTTP POST async via pg_net (non-blocking)
  SELECT net.http_post(
    url := webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', anon_key
    ),
    body := payload,
    timeout_milliseconds := 5000
  ) INTO request_id;

  -- Log untuk debugging (opsional, bisa dihapus di production)
  RAISE NOTICE 'Push webhook sent: request_id=%, table=%', request_id, TG_TABLE_NAME;

  RETURN NEW;
END;
$$;

-- Trigger tetap terpasang pada fungsi yang sama (definisi fungsi diperbarui).
GRANT EXECUTE ON FUNCTION public.notify_push_webhook() TO service_role;