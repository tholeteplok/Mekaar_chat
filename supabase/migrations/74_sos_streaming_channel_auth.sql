-- ==============================================================================
-- Migration: 74_sos_streaming_channel_auth.sql
--
-- Otorisasi RLS pada realtime.messages untuk kanal SOS WebRTC streaming
-- dengan format topik 'sos_stream:<sessionId>'.
--
-- Hanya korban (pemilik sesi) dan Guardian aktif korban yang diizinkan
-- melakukan LISTEN (SELECT) dan BROADCAST (INSERT) sinyal WebRTC SOS.
-- ==============================================================================

BEGIN;

-- ── 1. SELECT Policy (LISTEN kanal sos_stream:<sessionId>) ──
DROP POLICY IF EXISTS "SOS stream participants can listen" ON realtime.messages;
CREATE POLICY "SOS stream participants can listen"
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  NOT (topic LIKE 'sos_stream:%') OR
  (
    EXISTS (
      SELECT 1
      FROM public.sos_sessions ss
      WHERE ss.id::text = substring(topic FROM 'sos_stream:(.*)')
        AND ss.status = 'active'
        AND (
          ss.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM public.guardians g
            WHERE g.owner_id = ss.user_id
              AND g.guardian_id = auth.uid()
              AND g.status = 'active'
          )
        )
    )
  )
);

-- ── 2. INSERT Policy (BROADCAST sinyal di kanal sos_stream:<sessionId>) ──
DROP POLICY IF EXISTS "SOS stream participants can send" ON realtime.messages;
CREATE POLICY "SOS stream participants can send"
ON realtime.messages
FOR INSERT
TO authenticated
WITH CHECK (
  NOT (topic LIKE 'sos_stream:%') OR
  (
    EXISTS (
      SELECT 1
      FROM public.sos_sessions ss
      WHERE ss.id::text = substring(topic FROM 'sos_stream:(.*)')
        AND ss.status = 'active'
        AND (
          ss.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM public.guardians g
            WHERE g.owner_id = ss.user_id
              AND g.guardian_id = auth.uid()
              AND g.status = 'active'
          )
        )
    )
  )
);

COMMIT;
