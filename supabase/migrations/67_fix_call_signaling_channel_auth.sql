-- ==============================================================================
-- Migration: 67_fix_call_signaling_channel_auth.sql
--
-- Memperbaiki otorisasi RLS pada realtime.messages untuk topik 'room_call:<callId>'.
-- Menggantikan pencocokan room_id yang keliru di migration 27 menjadi
-- pencocokan calls.id dan memverifikasi auth.uid() adalah caller_id atau receiver_id.
-- ==============================================================================

BEGIN;

-- 1. Hapus policy lama dari migration 27
DROP POLICY IF EXISTS "Only room participants can listen to room calls" ON realtime.messages;
DROP POLICY IF EXISTS "Only room participants can send room calls" ON realtime.messages;
DROP POLICY IF EXISTS "Only call participants can listen to room calls" ON realtime.messages;
DROP POLICY IF EXISTS "Only call participants can send room calls" ON realtime.messages;

-- 2. Policy SELECT: Hanya caller atau receiver panggilan yang dapat menerima sinyal WebRTC
CREATE POLICY "Only call participants can listen to room calls"
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  NOT (topic LIKE 'room_call:%') OR
  (
    EXISTS (
      SELECT 1 
      FROM public.calls c
      WHERE c.id::text = substring(topic FROM 'room_call:(.*)')
        AND (c.caller_id = auth.uid() OR c.receiver_id = auth.uid())
    )
  )
);

-- 3. Policy INSERT: Hanya caller atau receiver panggilan yang dapat menyiarkan sinyal WebRTC
CREATE POLICY "Only call participants can send room calls"
ON realtime.messages
FOR INSERT
TO authenticated
WITH CHECK (
  NOT (topic LIKE 'room_call:%') OR
  (
    EXISTS (
      SELECT 1 
      FROM public.calls c
      WHERE c.id::text = substring(topic FROM 'room_call:(.*)')
        AND (c.caller_id = auth.uid() OR c.receiver_id = auth.uid())
    )
  )
);

COMMIT;
