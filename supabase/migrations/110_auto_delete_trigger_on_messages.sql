-- ==============================================================================
-- Migration: 110_auto_delete_trigger_on_messages.sql
--
-- Fail-Safe Server-Side Enforcer untuk Pesan Menghilang (Disappearing Messages):
-- Memastikan auto_delete_at dihitung dan dikunci secara otomatis dari jam server
-- (PostgreSQL) saat pesan baru dibuat, sehingga tidak bergantung pada ketepatan jam HP
-- atau manipulasi client-side.
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.enforce_message_auto_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_disappearing_hours INTEGER;
  v_scheduled_wipe_target_at TIMESTAMPTZ;
BEGIN
  -- Ambil aturan pesan menghilang dan pembersihan terjadwal dari chat_rooms
  SELECT disappearing_hours, scheduled_wipe_target_at
  INTO v_disappearing_hours, v_scheduled_wipe_target_at
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  -- 1. Prioritaskan scheduled wipe aktif di masa depan jika ada
  IF v_scheduled_wipe_target_at IS NOT NULL AND v_scheduled_wipe_target_at > now() THEN
    NEW.auto_delete_at := v_scheduled_wipe_target_at;
  -- 2. Jika disappearing_hours aktif (> 0), kunci auto_delete_at berdasarkan server time
  ELSIF v_disappearing_hours IS NOT NULL AND v_disappearing_hours > 0 THEN
    NEW.auto_delete_at := COALESCE(NEW.created_at, now()) + (v_disappearing_hours || ' hours')::INTERVAL;
  END IF;

  RETURN NEW;
END;
$$;

-- Pasang trigger BEFORE INSERT pada public.messages
DROP TRIGGER IF EXISTS trg_enforce_message_auto_delete ON public.messages;
CREATE TRIGGER trg_enforce_message_auto_delete
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_message_auto_delete();

-- Batasi hak eksekusi hanya ke authenticated dan service_role
REVOKE ALL ON FUNCTION public.enforce_message_auto_delete() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enforce_message_auto_delete() TO authenticated, service_role;

COMMIT;
