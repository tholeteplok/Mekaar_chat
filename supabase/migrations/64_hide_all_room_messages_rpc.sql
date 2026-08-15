-- ============================================================================
-- MEKAAR 3.0 Migration 64: Server-Side Batch Hide Room Messages RPC
--
-- Masalah: Clear chat history & delete chat sebelumnya melakukan download
--          seluruh ID pesan ke memori aplikasi lalu mengirimkan HTTP upsert massal.
--          Untuk ruangan dengan ribuan pesan, hal ini berisiko OOM / timeout.
--
-- Solusi:  Jalankan batch insert ke hidden_messages secara server-side dalam 1 transaksi
--          aman dengan SECURITY DEFINER dan search_path = public.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.hide_all_room_messages(p_room_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Pastikan pemanggil adalah partisipan dari room tersebut
  IF NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id AND profile_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not a participant of this room';
  END IF;

  -- Sisipkan seluruh ID pesan aktif ke hidden_messages milik pemanggil
  INSERT INTO public.hidden_messages (profile_id, message_id)
  SELECT v_user_id, id
  FROM public.messages
  WHERE room_id = p_room_id
  ON CONFLICT (profile_id, message_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hide_all_room_messages(UUID) TO authenticated;
