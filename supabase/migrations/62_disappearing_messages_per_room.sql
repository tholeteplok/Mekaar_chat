-- ==============================================================================
-- Migration: 62_disappearing_messages_per_room.sql
--
-- Perbaikan Bug Pesan Menghilang (Disappearing Messages):
-- Mengubah aturan pesan menghilang menjadi tersinkronisasi Per-Room (bukan Per-User).
-- Menambahkan kolom disappearing_hours ke chat_rooms dan fungsi RPC
-- set_room_disappearing_hours untuk sinkronisasi retroaktif pada pesan aktif.
-- ==============================================================================

BEGIN;

-- 1. Tambahkan kolom disappearing_hours ke tabel chat_rooms (0 = Mati / Pesan Abadi)
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS disappearing_hours INTEGER NOT NULL DEFAULT 0;

-- 2. Buat RPC set_room_disappearing_hours yang aman dengan search_path terisolasi
CREATE OR REPLACE FUNCTION public.set_room_disappearing_hours(p_room_id UUID, p_hours INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_hours < 0 THEN
    RAISE EXCEPTION 'disappearing hours tidak boleh negatif';
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

  -- Update setting level ruangan
  UPDATE public.chat_rooms
  SET disappearing_hours = p_hours
  WHERE id = p_room_id;

  -- Update auto_delete_at untuk SEMUA pesan aktif di room tersebut
  IF p_hours > 0 THEN
    UPDATE public.messages
    SET auto_delete_at = created_at + (p_hours || ' hours')::INTERVAL
    WHERE room_id = p_room_id
      AND is_deleted = false
      AND (auto_delete_at IS NULL OR auto_delete_at > now());
  ELSE
    -- Jika dinonaktifkan (Mati / 0), hapus waktu kedaluwarsa pada pesan
    UPDATE public.messages
    SET auto_delete_at = NULL
    WHERE room_id = p_room_id
      AND is_deleted = false;
  END IF;
END;
$$;

-- 3. Hardening permission: Berikan akses hanya ke authenticated users
REVOKE ALL ON FUNCTION public.set_room_disappearing_hours(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_room_disappearing_hours(UUID, INTEGER) TO authenticated;

COMMIT;
