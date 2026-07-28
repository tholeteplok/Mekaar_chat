-- 41_sos_push_triggers.sql
-- Trigger untuk SOS sessions → kirim webhook ke send-push-notification
-- Edge Function saat ada INSERT/UPDATE di tabel sos_sessions.
--
-- Menggunakan notify_push_webhook() yang sudah ada dari migration 39.
-- Setup: jalankan migration ini di Supabase SQL Editor.

BEGIN;

-- Trigger untuk SOS session baru (INSERT) → kirim push ke guardian
DROP TRIGGER IF EXISTS on_sos_insert_push_notify ON public.sos_sessions;
CREATE TRIGGER on_sos_insert_push_notify
  AFTER INSERT ON public.sos_sessions
  FOR EACH ROW
  WHEN (NEW.status = 'active')
  EXECUTE FUNCTION public.notify_push_webhook();

-- Trigger untuk update status SOS (UPDATE) → guardian tahu jika resolved
DROP TRIGGER IF EXISTS on_sos_update_push_notify ON public.sos_sessions;
CREATE TRIGGER on_sos_update_push_notify
  AFTER UPDATE ON public.sos_sessions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_push_webhook();

-- Pastikan service_role bisa execute fungsi webhook
GRANT EXECUTE ON FUNCTION public.notify_push_webhook() TO service_role;

COMMIT;
