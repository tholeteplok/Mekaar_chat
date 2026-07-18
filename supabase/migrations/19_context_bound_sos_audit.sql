-- Migration 19: Context-bound SOS audit
-- Privacy by default: only SOS incident metadata may be written as new audit data.

ALTER TABLE public.security_logs
  ADD COLUMN IF NOT EXISTS sos_session_id UUID REFERENCES public.sos_sessions(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS event_scope TEXT NOT NULL DEFAULT 'sos';

-- Backfill only rows whose historical details contain a valid SOS session UUID.
UPDATE public.security_logs AS logs
SET sos_session_id = sessions.id,
    event_scope = 'sos'
FROM public.sos_sessions AS sessions
WHERE logs.sos_session_id IS NULL
  AND logs.details ? 'session_id'
  AND logs.details->>'session_id' = sessions.id::TEXT;

CREATE INDEX IF NOT EXISTS idx_security_logs_sos_timeline
  ON public.security_logs (user_id, sos_session_id, created_at DESC)
  WHERE deleted_at IS NULL AND sos_session_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_security_logs_sos_boundary
  ON public.security_logs (sos_session_id, event_type)
  WHERE event_type IN ('sos_started', 'sos_ended');

-- Chat deletion and log deletion are privacy actions, not SOS audit events.
DROP TRIGGER IF EXISTS tr_log_message_deletion ON public.messages;
DROP FUNCTION IF EXISTS public.log_message_deletion();
DROP TRIGGER IF EXISTS tr_log_security_log_delete ON public.security_logs;
DROP FUNCTION IF EXISTS public.log_security_log_delete();

-- Database-owned lifecycle audit. ON CONFLICT makes retries idempotent.
CREATE OR REPLACE FUNCTION public.log_sos_activity()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.security_logs (
      user_id, sos_session_id, event_scope, event_type, details
    ) VALUES (
      NEW.user_id,
      NEW.id,
      'sos',
      'sos_started',
      jsonb_build_object(
        'gps_enabled', NEW.gps_enabled,
        'mic_enabled', NEW.mic_enabled,
        'video_enabled', NEW.video_enabled,
        'started_at', NEW.started_at
      )
    ) ON CONFLICT DO NOTHING;
  ELSIF TG_OP = 'UPDATE'
      AND OLD.status = 'active'
      AND NEW.status <> 'active' THEN
    INSERT INTO public.security_logs (
      user_id, sos_session_id, event_scope, event_type, details
    ) VALUES (
      NEW.user_id,
      NEW.id,
      'sos',
      'sos_ended',
      jsonb_build_object(
        'ended_at', NEW.ended_at,
        'ended_reason', NEW.ended_reason,
        'status', NEW.status
      )
    ) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tr_log_sos_activity ON public.sos_sessions;
CREATE TRIGGER tr_log_sos_activity
AFTER INSERT OR UPDATE ON public.sos_sessions
FOR EACH ROW EXECUTE FUNCTION public.log_sos_activity();

-- Controlled writer for events produced while a session is active.
CREATE OR REPLACE FUNCTION public.log_sos_event(
  target_session_id UUID,
  target_event_type TEXT,
  event_details JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
  current_user_id UUID := auth.uid();
  session_owner UUID;
  session_status TEXT;
  inserted_id UUID;
  allowed_events CONSTANT TEXT[] := ARRAY[
    'guardian_alert_sent',
    'guardian_alert_failed',
    'guardian_location_accessed',
    'guardian_audio_accessed',
    'guardian_video_accessed',
    'emergency_media_sent',
    'sos_degraded'
  ];
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT target_event_type = ANY(allowed_events) THEN
    RAISE EXCEPTION 'Unsupported SOS audit event';
  END IF;

  SELECT user_id, status
  INTO session_owner, session_status
  FROM public.sos_sessions
  WHERE id = target_session_id;

  IF session_owner IS NULL OR session_status <> 'active' THEN
    RAISE EXCEPTION 'SOS session is not active';
  END IF;

  IF current_user_id <> session_owner AND NOT EXISTS (
    SELECT 1
    FROM public.guardians
    WHERE owner_id = session_owner
      AND guardian_id = current_user_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now())
  ) THEN
    RAISE EXCEPTION 'Not authorized for this SOS session';
  END IF;

  -- Explicitly reject common communication/sensor payload fields.
  IF event_details ?| ARRAY[
    'content', 'message', 'media_url', 'transcript',
    'latitude', 'longitude', 'email', 'phone', 'contacts'
  ] THEN
    RAISE EXCEPTION 'Sensitive payload is not allowed in SOS audit';
  END IF;

  INSERT INTO public.security_logs (
    user_id, sos_session_id, event_scope, event_type, details
  ) VALUES (
    session_owner,
    target_session_id,
    'sos',
    target_event_type,
    COALESCE(event_details, '{}'::JSONB) || jsonb_build_object('actor_id', current_user_id)
  )
  RETURNING id INTO inserted_id;

  RETURN inserted_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.log_sos_event(UUID, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_sos_event(UUID, TEXT, JSONB) TO authenticated;

-- Clients may read through RLS, but all mutations are database/RPC owned.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.security_logs FROM authenticated;

-- Retention helper. Schedule externally (for example Supabase Cron) once per day.
CREATE OR REPLACE FUNCTION public.cleanup_expired_sos_audit()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.security_logs AS logs
  USING public.sos_sessions AS sessions
  WHERE logs.sos_session_id = sessions.id
    AND sessions.status <> 'active'
    AND COALESCE(sessions.ended_at, sessions.started_at) < now() - INTERVAL '90 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.cleanup_expired_sos_audit() FROM PUBLIC;
