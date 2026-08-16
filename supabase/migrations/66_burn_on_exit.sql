-- ==============================================================================
-- Migration: 66_burn_on_exit.sql
--
-- Fitur Keamanan: Hapus Pesan Saat Keluar Layar Obrolan (Burn on Exit).
-- Menambahkan kolom burn_on_exit ke tabel chat_rooms, serta RPC
-- set_room_burn_on_exit dan execute_room_burn_on_exit.
-- ==============================================================================

BEGIN;

-- 1. Tambahkan kolom burn_on_exit ke tabel chat_rooms
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS burn_on_exit BOOLEAN NOT NULL DEFAULT false;

-- 2. Buat RPC set_room_burn_on_exit
CREATE OR REPLACE FUNCTION public.set_room_burn_on_exit(
  p_room_id UUID,
  p_enabled BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verifikasi pemanggil adalah anggota sah dari room tersebut
  IF NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- Update setelan di chat_rooms
  UPDATE public.chat_rooms
  SET burn_on_exit = p_enabled
  WHERE id = p_room_id;
END;
$$;

-- 3. Buat RPC execute_room_burn_on_exit
CREATE OR REPLACE FUNCTION public.execute_room_burn_on_exit(
  p_room_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_burn_enabled BOOLEAN;
BEGIN
  -- Verifikasi pemanggil adalah anggota sah dari room tersebut
  IF NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- Periksa apakah mode burn_on_exit aktif untuk ruangan ini
  SELECT burn_on_exit INTO v_burn_enabled
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_burn_enabled IS TRUE THEN
    -- Hapus seluruh riwayat pesan di ruangan ini
    DELETE FROM public.messages
    WHERE room_id = p_room_id;
  END IF;
END;
$$;

-- 4. Berikan hak akses eksekusi ke authenticated users
GRANT EXECUTE ON FUNCTION public.set_room_burn_on_exit(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.execute_room_burn_on_exit(UUID) TO authenticated;

COMMIT;
