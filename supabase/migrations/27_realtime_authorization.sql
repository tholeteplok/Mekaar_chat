-- Enable Row Level Security on the realtime schema for messages (managed by Supabase system)
-- ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Only room participants can listen to room calls" ON realtime.messages;
DROP POLICY IF EXISTS "Only room participants can send room calls" ON realtime.messages;

-- Policy for listening (SELECT) on signaling channels
CREATE POLICY "Only room participants can listen to room calls"
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  NOT (topic LIKE 'room_call:%') OR
  (
    EXISTS (
      SELECT 1 
      FROM public.room_participants rp
      WHERE rp.room_id::text = substring(topic from 'room_call:(.*)')
        AND rp.profile_id = auth.uid()
    )
  )
);

-- Policy for sending (INSERT) on signaling channels
CREATE POLICY "Only room participants can send room calls"
ON realtime.messages
FOR INSERT
TO authenticated
WITH CHECK (
  NOT (topic LIKE 'room_call:%') OR
  (
    EXISTS (
      SELECT 1 
      FROM public.room_participants rp
      WHERE rp.room_id::text = substring(topic from 'room_call:(.*)')
        AND rp.profile_id = auth.uid()
    )
  )
);
