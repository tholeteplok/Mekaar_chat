-- Migration 20: room-scoped screenshot protection with server-owned freshness metadata.

ALTER TABLE public.room_participants
  ADD COLUMN IF NOT EXISTS screenshot_protection_enabled BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.room_participants
  ADD COLUMN IF NOT EXISTS screenshot_protection_updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.room_participants
SET screenshot_protection_enabled = TRUE
WHERE screenshot_protection_enabled IS NULL;

UPDATE public.room_participants
SET screenshot_protection_updated_at = now()
WHERE screenshot_protection_updated_at IS NULL;

CREATE OR REPLACE FUNCTION public.set_screenshot_protection_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.screenshot_protection_enabled IS DISTINCT FROM OLD.screenshot_protection_enabled THEN
    NEW.screenshot_protection_updated_at = now();
  ELSE
    NEW.screenshot_protection_updated_at = OLD.screenshot_protection_updated_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_participants_screenshot_protection_timestamp
  ON public.room_participants;
CREATE TRIGGER room_participants_screenshot_protection_timestamp
  BEFORE UPDATE OF screenshot_protection_enabled
  ON public.room_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_screenshot_protection_updated_at();

CREATE OR REPLACE FUNCTION public.set_room_screenshot_protection(
  p_room_id UUID,
  p_enabled BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  updated BOOLEAN;
BEGIN
  UPDATE public.room_participants
  SET screenshot_protection_enabled = p_enabled
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
  RETURNING screenshot_protection_enabled INTO updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room participant not found';
  END IF;

  RETURN updated;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_room_screenshot_protection(
  p_room_id UUID
)
RETURNS TABLE (
  effective BOOLEAN,
  caller_enabled BOOLEAN,
  protector_count BIGINT,
  participant_count BIGINT,
  last_change TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Room participant not found';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(bool_or(rp.screenshot_protection_enabled), TRUE),
    COALESCE(
      bool_or(rp.screenshot_protection_enabled)
        FILTER (WHERE rp.profile_id = auth.uid()),
      TRUE
    ),
    COUNT(*) FILTER (WHERE rp.screenshot_protection_enabled),
    COUNT(*)::BIGINT,
    MAX(rp.screenshot_protection_updated_at)
  FROM public.room_participants rp
  WHERE rp.room_id = p_room_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_room_screenshot_protection(UUID, BOOLEAN)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_room_screenshot_protection(UUID, BOOLEAN)
  TO authenticated;

REVOKE ALL ON FUNCTION public.get_room_screenshot_protection(UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_room_screenshot_protection(UUID)
  TO authenticated;
