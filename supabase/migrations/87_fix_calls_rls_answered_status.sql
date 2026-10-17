-- Migration 87: Fix calls RLS update policy to allow caller updates when status is answered
-- Memungkinkan caller memperbarui row panggilan saat statusnya answered (misalnya mencatat started_at / durasi)
-- tanpa melanggar RLS 42501 Forbidden.

DROP POLICY IF EXISTS "Allow participants to update calls" ON public.calls;

CREATE POLICY "Allow participants to update calls" ON public.calls
  FOR UPDATE TO authenticated
  USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  )
  WITH CHECK (
    (
      auth.uid() = caller_id 
      AND status IN ('ringing', 'answered', 'ended', 'missed', 'failed', 'busy')
    )
    OR (
      auth.uid() = receiver_id 
      AND status IN ('ringing', 'answered', 'declined', 'ended', 'busy', 'failed')
    )
  );
