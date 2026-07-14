-- Migration 11: Allow authenticated users to update their own participant record in room_participants
-- Essential for updating last_read_at (fallback), history_cleared_at, and deleted_at.

DROP POLICY IF EXISTS "Users can update own room participant record" ON public.room_participants;

CREATE POLICY "Users can update own room participant record" ON public.room_participants
  FOR UPDATE TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());
