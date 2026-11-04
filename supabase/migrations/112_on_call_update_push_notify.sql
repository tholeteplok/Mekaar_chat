-- Migration 112: on_call_update_push_notify.sql
-- Trigger untuk mengirim push webhook saat status panggilan di-update (missed, ended, declined, failed)
-- agar perangkat penerima dapat membatalkan ringtone & notifikasi panggilan masuk seketika
-- serta menampilkan notifikasi panggilan tak terjawab jika statusnya missed.

BEGIN;

DROP TRIGGER IF EXISTS on_call_update_push_notify ON public.calls;

CREATE TRIGGER on_call_update_push_notify
  AFTER UPDATE OF status ON public.calls
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('missed', 'ended', 'declined', 'failed'))
  EXECUTE FUNCTION public.notify_push_webhook();

COMMIT;
