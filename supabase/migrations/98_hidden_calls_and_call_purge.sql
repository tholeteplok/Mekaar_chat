-- ==============================================================================
-- Migration: 98_hidden_calls_and_call_purge.sql
-- Description:
-- 1. Buat tabel public.hidden_calls untuk mencatat riwayat panggilan yang disembunyikan per pengguna.
-- 2. Buat RPC public.hide_all_room_calls untuk menyembunyikan seluruh panggilan kamar saat hapus/bersihkan obrolan.
-- 3. Perbarui RPC public.delete_contact_and_chat agar riwayat panggilan bilateral ikut disembunyikan saat kontak dihapus.
-- ==============================================================================

-- 1. Buat tabel hidden_calls
CREATE TABLE IF NOT EXISTS public.hidden_calls (
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  call_id UUID NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
  hidden_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (profile_id, call_id)
);

CREATE INDEX IF NOT EXISTS idx_hidden_calls_profile_id ON public.hidden_calls(profile_id);
CREATE INDEX IF NOT EXISTS idx_hidden_calls_call_id ON public.hidden_calls(call_id);

-- RLS untuk hidden_calls
ALTER TABLE public.hidden_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own hidden calls" ON public.hidden_calls;
CREATE POLICY "Users can manage their own hidden calls"
  ON public.hidden_calls
  FOR ALL TO authenticated
  USING (auth.uid() = profile_id)
  WITH CHECK (auth.uid() = profile_id);

GRANT ALL ON TABLE public.hidden_calls TO authenticated;

-- 2. RPC hide_all_room_calls untuk menyembunyikan panggilan suatu room secara atomik di sisi server
CREATE OR REPLACE FUNCTION public.hide_all_room_calls(p_room_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
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

  INSERT INTO public.hidden_calls (profile_id, call_id)
  SELECT v_user_id, id
  FROM public.calls
  WHERE room_id = p_room_id
  ON CONFLICT (profile_id, call_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.hide_all_room_calls(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hide_all_room_calls(UUID) TO authenticated, service_role;

-- 3. Perbarui RPC delete_contact_and_chat agar panggilan juga disembunyikan
CREATE OR REPLACE FUNCTION public.delete_contact_and_chat(p_contact_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_room_id UUID;
  now_iso TIMESTAMPTZ := now();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Hapus dari daftar kontak pengguna pemanggil
  DELETE FROM public.user_contacts
  WHERE user_id = v_caller_id AND contact_user_id = p_contact_user_id;

  -- 2. Cari semua kamar obrolan bilateral (normal / guardian)
  FOR v_room_id IN
    SELECT rp1.room_id
    FROM public.room_participants rp1
    JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
    JOIN public.chat_rooms cr ON cr.id = rp1.room_id
    WHERE rp1.profile_id = v_caller_id
      AND rp2.profile_id = p_contact_user_id
      AND cr.room_type IN ('normal', 'guardian')
  LOOP
    -- Tandai obrolan terhapus dan hapus riwayat untuk pemanggil
    UPDATE public.room_participants
    SET deleted_at = now_iso,
        history_cleared_at = now_iso
    WHERE room_id = v_room_id AND profile_id = v_caller_id;

    -- Sembunyikan pesan di kamar tersebut bagi pemanggil
    INSERT INTO public.hidden_messages (profile_id, message_id)
    SELECT v_caller_id, m.id
    FROM public.messages m
    WHERE m.room_id = v_room_id
    ON CONFLICT (profile_id, message_id) DO NOTHING;

    -- Sembunyikan panggilan di kamar tersebut bagi pemanggil
    INSERT INTO public.hidden_calls (profile_id, call_id)
    SELECT v_caller_id, c.id
    FROM public.calls c
    WHERE c.room_id = v_room_id
    ON CONFLICT (profile_id, call_id) DO NOTHING;
  END LOOP;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_contact_and_chat(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_contact_and_chat(UUID) TO authenticated, service_role;
