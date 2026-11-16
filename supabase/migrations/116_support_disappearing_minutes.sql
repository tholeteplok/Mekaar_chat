-- ==============================================================================
-- Migration: 116_support_disappearing_minutes.sql
--
-- Dukungan Presisi Satuan Menit untuk Pesan Menghilang (Disappearing Messages):
-- 1. Menambahkan kolom disappearing_minutes ke chat_rooms (0 = Mati / Abadi).
-- 2. Membuat RPC set_room_disappearing_duration(p_room_id, p_minutes).
-- 3. Memperbarui RPC set_room_disappearing_hours agar tetap kompatibel.
-- 4. Memperbarui trigger enforce_message_auto_delete untuk menghitung auto_delete_at
--    berbasis menit dengan presisi server PostgreSQL.
-- ==============================================================================

BEGIN;

-- 1. Tambah kolom disappearing_minutes ke tabel chat_rooms
ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS disappearing_minutes INTEGER NOT NULL DEFAULT 0;

-- 2. Backfill data eksisting dari disappearing_hours ke disappearing_minutes
UPDATE public.chat_rooms
SET disappearing_minutes = disappearing_hours * 60
WHERE disappearing_hours > 0 AND (disappearing_minutes IS NULL OR disappearing_minutes = 0);

-- 3. Buat RPC set_room_disappearing_duration yang mendukung menit
CREATE OR REPLACE FUNCTION public.set_room_disappearing_duration(
  p_room_id UUID,
  p_minutes INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hours INTEGER;
BEGIN
  IF p_minutes < 0 THEN
    RAISE EXCEPTION 'disappearing minutes tidak boleh negatif';
  END IF;

  -- Hitung padanan jam untuk kompatibilitas backward
  v_hours := CEIL(p_minutes::NUMERIC / 60.0)::INTEGER;

  -- Update pengaturan ruangan
  UPDATE public.chat_rooms
  SET disappearing_minutes = p_minutes,
      disappearing_hours = v_hours
  WHERE id = p_room_id;

  -- Sinkronkan retroaktif pesan aktif di ruangan
  IF p_minutes > 0 THEN
    UPDATE public.messages
    SET auto_delete_at = created_at + (p_minutes || ' minutes')::INTERVAL
    WHERE room_id = p_room_id
      AND deleted_at IS NULL;
  ELSE
    UPDATE public.messages
    SET auto_delete_at = NULL
    WHERE room_id = p_room_id
      AND deleted_at IS NULL;
  END IF;
END;
$$;

-- 4. Perbarui RPC lama set_room_disappearing_hours agar menyinkronkan disappearing_minutes
CREATE OR REPLACE FUNCTION public.set_room_disappearing_hours(
  p_room_id UUID,
  p_hours INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delegasikan ke set_room_disappearing_duration dengan konversi jam ke menit
  PERFORM public.set_room_disappearing_duration(p_room_id, p_hours * 60);
END;
$$;

-- 5. Perbarui server trigger enforce_message_auto_delete untuk memprioritaskan menit
CREATE OR REPLACE FUNCTION public.enforce_message_auto_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_disappearing_minutes INTEGER;
  v_disappearing_hours INTEGER;
  v_effective_minutes INTEGER := 0;
  v_scheduled_wipe_target_at TIMESTAMPTZ;
BEGIN
  -- Ambil aturan pesan menghilang dan pembersihan terjadwal dari chat_rooms
  SELECT disappearing_minutes, disappearing_hours, scheduled_wipe_target_at
  INTO v_disappearing_minutes, v_disappearing_hours, v_scheduled_wipe_target_at
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  -- 1. Prioritaskan scheduled wipe aktif di masa depan jika ada
  IF v_scheduled_wipe_target_at IS NOT NULL AND v_scheduled_wipe_target_at > now() THEN
    NEW.auto_delete_at := v_scheduled_wipe_target_at;
  ELSE
    -- 2. Tentukan durasi efektif dalam menit
    IF v_disappearing_minutes IS NOT NULL AND v_disappearing_minutes > 0 THEN
      v_effective_minutes := v_disappearing_minutes;
    ELSIF v_disappearing_hours IS NOT NULL AND v_disappearing_hours > 0 THEN
      v_effective_minutes := v_disappearing_hours * 60;
    END IF;

    -- Kunci auto_delete_at berdasarkan server time jika disappearing aktif
    IF v_effective_minutes > 0 THEN
      NEW.auto_delete_at := COALESCE(NEW.created_at, now()) + (v_effective_minutes || ' minutes')::INTERVAL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 6. Hak akses eksekusi
REVOKE ALL ON FUNCTION public.set_room_disappearing_duration(UUID, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_disappearing_duration(UUID, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_room_disappearing_hours(UUID, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_disappearing_hours(UUID, INTEGER) TO authenticated, service_role;

COMMIT;
