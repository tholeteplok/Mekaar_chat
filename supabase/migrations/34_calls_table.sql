-- Migration 34: Stateful calls table for real-time signaling and invitations
-- Additive only - safe to run on existing databases

CREATE TABLE IF NOT EXISTS public.calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  caller_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  call_type TEXT NOT NULL CHECK (call_type IN ('voice', 'video')),
  status TEXT NOT NULL CHECK (status IN ('ringing', 'answered', 'declined', 'missed', 'ended', 'failed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for calls
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users to view their own calls" ON public.calls;
CREATE POLICY "Allow users to view their own calls" ON public.calls
  FOR SELECT TO authenticated USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  );

DROP POLICY IF EXISTS "Allow callers to insert calls" ON public.calls;
CREATE POLICY "Allow callers to insert calls" ON public.calls
  FOR INSERT TO authenticated WITH CHECK (
    caller_id = auth.uid()
  );

DROP POLICY IF EXISTS "Allow participants to update calls" ON public.calls;
CREATE POLICY "Allow participants to update calls" ON public.calls
  FOR UPDATE TO authenticated USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  );

-- Enable Realtime publication for calls table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
