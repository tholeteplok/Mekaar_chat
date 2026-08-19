-- ==============================================================================
-- Migration: 68_fix_calls_rls_room_validation.sql
--
-- 1. Menambahkan fungsi helper is_call_authorized() untuk memvalidasi kepesertaan room
--    pada level database PostgreSQL (SECURITY DEFINER).
-- 2. Memperbarui RLS policy INSERT pada tabel calls agar wajib memverifikasi
--    bahwa caller dan receiver adalah partisipan room yang sah.
-- 3. Memperbarui RLS policy UPDATE pada tabel calls dengan WITH CHECK untuk
--    mencegah manipulasi identitas pemanggil/penerima atau room.
-- ==============================================================================

BEGIN;

-- 1. Helper function untuk validasi otorisasi panggilan di level DB
CREATE OR REPLACE FUNCTION public.is_call_authorized(
  p_caller_id UUID,
  p_receiver_id UUID,
  p_room_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Pastikan caller & receiver sama-sama anggota room
  RETURN EXISTS (
    SELECT 1
    FROM public.room_participants rp_caller
    JOIN public.room_participants rp_receiver
      ON rp_receiver.room_id = rp_caller.room_id
    WHERE rp_caller.room_id = p_room_id
      AND rp_caller.profile_id = p_caller_id
      AND rp_receiver.profile_id = p_receiver_id
  );
END;
$$;

-- 2. Perbarui policy INSERT pada tabel calls
DROP POLICY IF EXISTS "Allow callers to insert calls" ON public.calls;

CREATE POLICY "Allow callers to insert calls" ON public.calls
  FOR INSERT TO authenticated
  WITH CHECK (
    caller_id = auth.uid()
    AND public.is_call_authorized(caller_id, receiver_id, room_id)
  );

-- 3. Perbarui policy UPDATE pada tabel calls dengan proteksi integritas kolom
DROP POLICY IF EXISTS "Allow participants to update calls" ON public.calls;

CREATE POLICY "Allow participants to update calls" ON public.calls
  FOR UPDATE TO authenticated
  USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  )
  WITH CHECK (
    -- caller_id, receiver_id, dan room_id tidak boleh diubah
    caller_id = (SELECT c.caller_id FROM public.calls c WHERE c.id = calls.id)
    AND receiver_id = (SELECT c.receiver_id FROM public.calls c WHERE c.id = calls.id)
    AND room_id = (SELECT c.room_id FROM public.calls c WHERE c.id = calls.id)
    -- Transisi status: hanya caller atau receiver yang berhak mengubah status
    AND (
      (auth.uid() = caller_id AND status IN ('ringing', 'ended', 'missed', 'failed', 'busy'))
      OR (auth.uid() = receiver_id AND status IN ('ringing', 'answered', 'declined', 'ended', 'busy', 'failed'))
    )
  );

COMMIT;
