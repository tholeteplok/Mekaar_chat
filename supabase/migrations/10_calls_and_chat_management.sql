-- Migration 10: Call logs and chat history clear/delete markers
-- Additive only - safe to run on existing databases

-- ─────────────────────────────────────────
-- 1. Call logs table
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  caller_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  call_type TEXT NOT NULL CHECK (call_type IN ('voice', 'video')),
  status TEXT NOT NULL CHECK (status IN ('missed', 'rejected', 'connected', 'ended')),
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for call_logs
ALTER TABLE public.call_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own call logs" ON public.call_logs
  FOR SELECT TO authenticated USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  );

CREATE POLICY "Allow users to insert call logs" ON public.call_logs
  FOR INSERT TO authenticated WITH CHECK (
    caller_id = auth.uid()
  );

CREATE POLICY "Allow callers to update call logs" ON public.call_logs
  FOR UPDATE TO authenticated USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  );

-- ─────────────────────────────────────────
-- 2. History clearing and deletion metadata
-- ─────────────────────────────────────────
ALTER TABLE public.room_participants 
  ADD COLUMN IF NOT EXISTS history_cleared_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
