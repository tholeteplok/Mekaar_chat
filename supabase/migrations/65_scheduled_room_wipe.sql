-- ==============================================================================
-- Migration: 65_scheduled_room_wipe.sql
--
-- Fitur Pembersihan Terjadwal Berbasis Waktu (Scheduled Room Wipe):
-- Menambahkan kolom scheduled_wipe_time, scheduled_wipe_mode, dan
-- scheduled_wipe_target_at ke chat_rooms, serta RPC set_room_scheduled_wipe
-- dan execute_room_scheduled_wipe.
-- ==============================================================================

BEGIN;

-- 1. Tambahkan kolom ke tabel chat_rooms
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS scheduled_wipe_time TIME NULL,
  ADD COLUMN IF NOT EXISTS scheduled_wipe_mode VARCHAR(20) NOT NULL DEFAULT 'off',
  ADD COLUMN IF NOT EXISTS scheduled_wipe_target_at TIMESTAMPTZ NULL;

-- 2. Buat RPC set_room_scheduled_wipe
CREATE OR REPLACE FUNCTION public.set_room_scheduled_wipe(
  p_room_id UUID,
  p_time TIME,
  p_mode VARCHAR(20),
  p_target_at TIMESTAMPTZ
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_disappearing_hours INTEGER;
BEGIN
  -- Validasi mode
  IF p_mode NOT IN ('off', 'one_shot', 'daily') THEN
    RAISE EXCEPTION 'Mode pembersihan tidak valid: %', p_mode;
  END IF;

  -- Verifikasi pemanggil adalah anggota sah dari room tersebut
  IF NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- Ambil setting disappearing_hours ruangan saat ini
  SELECT disappearing_hours INTO v_disappearing_hours
  FROM public.chat_rooms
  WHERE id = p_room_id;

  -- Update setelan di chat_rooms
  IF p_mode = 'off' THEN
    UPDATE public.chat_rooms
    SET scheduled_wipe_time = NULL,
        scheduled_wipe_mode = 'off',
        scheduled_wipe_target_at = NULL
    WHERE id = p_room_id;

    -- Kembalikan auto_delete_at ke aturan disappearing_hours atau NULL
    IF v_disappearing_hours IS NOT NULL AND v_disappearing_hours > 0 THEN
      UPDATE public.messages
      SET auto_delete_at = created_at + (v_disappearing_hours || ' hours')::INTERVAL
      WHERE room_id = p_room_id
        AND is_deleted = false;
    ELSE
      UPDATE public.messages
      SET auto_delete_at = NULL
      WHERE room_id = p_room_id
        AND is_deleted = false;
    END IF;
  ELSE
    UPDATE public.chat_rooms
    SET scheduled_wipe_time = p_time,
        scheduled_wipe_mode = p_mode,
        scheduled_wipe_target_at = p_target_at
    WHERE id = p_room_id;

    -- Update auto_delete_at untuk SEMUA pesan aktif di room ke target pembersihan terjadwal
    IF p_target_at IS NOT NULL THEN
      UPDATE public.messages
      SET auto_delete_at = LEAST(COALESCE(auto_delete_at, p_target_at), p_target_at)
      WHERE room_id = p_room_id
        AND is_deleted = false;
    END IF;
  END IF;
END;
$$;

-- 3. Buat RPC execute_room_scheduled_wipe
CREATE OR REPLACE FUNCTION public.execute_room_scheduled_wipe(p_room_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_mode VARCHAR(20);
  v_time TIME;
  v_target_at TIMESTAMPTZ;
BEGIN
  -- Verifikasi pemanggil atau sistem
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- Hapus semua pesan di room
  DELETE FROM public.messages
  WHERE room_id = p_room_id
    AND created_at <= now();
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  -- Ambil status mode saat ini
  SELECT scheduled_wipe_mode, scheduled_wipe_time, scheduled_wipe_target_at
  INTO v_mode, v_time, v_target_at
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_mode = 'one_shot' THEN
    UPDATE public.chat_rooms
    SET scheduled_wipe_mode = 'off',
        scheduled_wipe_time = NULL,
        scheduled_wipe_target_at = NULL
    WHERE id = p_room_id;
  ELSIF v_mode = 'daily' THEN
    -- Majukan target ke hari berikutnya pada jam yang sama
    UPDATE public.chat_rooms
    SET scheduled_wipe_target_at = (v_target_at + INTERVAL '1 day')
    WHERE id = p_room_id;
  END IF;

  RETURN v_deleted_count;
END;
$$;

-- 4. Perbarui fungsi pembersih global purge_expired_messages
CREATE OR REPLACE FUNCTION public.purge_expired_messages()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count INTEGER := 0;
  r RECORD;
BEGIN
  -- A. Eksekusi pembersihan terjadwal untuk room yang sudah mencapai target
  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE scheduled_wipe_mode != 'off'
      AND scheduled_wipe_target_at IS NOT NULL
      AND scheduled_wipe_target_at <= now()
  LOOP
    PERFORM public.execute_room_scheduled_wipe(r.id);
  END LOOP;

  -- B. Hard delete pesan individual yang melewati auto_delete_at
  DELETE FROM public.messages
  WHERE auto_delete_at IS NOT NULL
    AND auto_delete_at < now();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RETURN deleted_count;
END;
$$;

-- 5. Berikan izin eksekusi ke authenticated users
REVOKE ALL ON FUNCTION public.set_room_scheduled_wipe(UUID, TIME, VARCHAR, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_room_scheduled_wipe(UUID, TIME, VARCHAR, TIMESTAMPTZ) TO authenticated;

REVOKE ALL ON FUNCTION public.execute_room_scheduled_wipe(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_room_scheduled_wipe(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated;

COMMIT;
