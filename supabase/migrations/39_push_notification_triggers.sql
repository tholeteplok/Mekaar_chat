-- 39_push_notification_triggers.sql
-- Database triggers yang mengirim webhook ke send-push-notification
-- Edge Function saat ada INSERT di tabel messages atau calls.
--
-- Menggunakan pg_net (migration 36) untuk HTTP POST async.
--
-- ── Setup ─────────────────────────────────────────────────────────────────
-- 1. Deploy Edge Function terlebih dahulu:
--      supabase functions deploy send-push-notification
--
-- 2. Set webhook URL di Supabase SQL Editor (ganti <project-ref>):
--      ALTER DATABASE postgres SET app.settings.push_webhook_url =
--        'https://<project-ref>.supabase.co/functions/v1/send-push-notification';
--      ALTER DATABASE postgres SET app.settings.anon_key = '<anon-key>';
--
-- 3. Jalankan migration ini di Supabase SQL Editor.

BEGIN;

-- ── Function: kirim webhook ke Edge Function ─────────────────────────────
-- Fungsi ini dipanggil oleh trigger dan mengirim record baru ke Edge Function
-- via pg_net (async HTTP POST).

CREATE OR REPLACE FUNCTION public.notify_push_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  webhook_url text;
  payload jsonb;
  request_id bigint;
BEGIN
  -- URL Edge Function (ganti <project-ref> dengan project ID Supabase kamu)
  -- Bisa juga di-set via ALTER FUNCTION setelah deployment
  webhook_url := current_setting('app.settings.push_webhook_url', true);

  -- Fallback ke env var jika setting tidak ada
  IF webhook_url IS NULL OR webhook_url = '' THEN
    webhook_url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-push-notification';
  END IF;

  -- Skip jika URL masih kosong (belum dikonfigurasi)
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE WARNING 'push_webhook_url belum dikonfigurasi, skip push notification';
    RETURN NEW;
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
      'apikey', current_setting('app.settings.anon_key', true)
    ),
    body := payload,
    timeout_milliseconds := 5000
  ) INTO request_id;

  -- Log untuk debugging (opsional, bisa dihapus di production)
  RAISE NOTICE 'Push webhook sent: request_id=%, table=%', request_id, TG_TABLE_NAME;

  RETURN NEW;
END;
$$;

-- ── Trigger: messages INSERT → push notification ─────────────────────────
-- Trigger ini fire setiap kali pesan baru diinsert.
-- Edge Function akan filter (skip system messages, deleted, dll).

DROP TRIGGER IF EXISTS on_message_insert_push_notify ON public.messages;
CREATE TRIGGER on_message_insert_push_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_webhook();

-- ── Trigger: calls INSERT → push notification ────────────────────────────
-- Trigger ini fire setiap kali panggilan baru diinsert.
-- Edge Function akan handle berdasarkan status (ringing = push, lainnya skip).

DROP TRIGGER IF EXISTS on_call_insert_push_notify ON public.calls;
CREATE TRIGGER on_call_insert_push_notify
  AFTER INSERT ON public.calls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_webhook();

-- ── Grant permissions ────────────────────────────────────────────────────
-- Pastikan service_role bisa execute fungsi webhook
GRANT EXECUTE ON FUNCTION public.notify_push_webhook() TO service_role;

COMMIT;
