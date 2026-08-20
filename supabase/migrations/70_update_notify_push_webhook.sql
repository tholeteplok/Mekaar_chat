-- 70_update_notify_push_webhook.sql
-- Ganti sumber konfigurasi push dari GUC (`app.settings.*`) ke tabel `public.app_config`
-- dengan proteksi 100% fail-safe (tidak pernah membatalkan INSERT pesan/SOS jika webhook error).
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
SET search_path = public, extensions, pg_temp
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

  -- Proteksi: Abaikan jika URL masih kosong atau masih berupa placeholder '<...>'
  IF webhook_url IS NULL OR webhook_url = '' OR webhook_url LIKE '%<%>%' THEN
    RETURN NEW;
  END IF;

  -- anon_key untuk header apikey (opsional, Edge Function pakai service role).
  SELECT value INTO anon_key FROM public.app_config WHERE key = 'anon_key';
  IF anon_key IS NULL OR anon_key = '' OR anon_key LIKE '%<%>%' THEN
    anon_key := current_setting('app.settings.anon_key', true);
  END IF;

  -- Bangun payload sesuai format pg_net webhook
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  -- 4) Fail-Safe HTTP POST via pg_net (isolasi error agar tidak menggagalkan transaksi pesan/SOS)
  BEGIN
    SELECT net.http_post(
      url := webhook_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', anon_key
      ),
      body := payload,
      timeout_milliseconds := 5000
    ) INTO request_id;

    RAISE NOTICE 'Push webhook sent: request_id=%, table=%', request_id, TG_TABLE_NAME;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Push webhook call failed (table: %, error: %)', TG_TABLE_NAME, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Pastikan service_role memiliki hak eksekusi
GRANT EXECUTE ON FUNCTION public.notify_push_webhook() TO service_role;