-- Migration 52: room-scoped forwarding protection with server-owned freshness metadata.

ALTER TABLE public.room_participants
  ADD COLUMN IF NOT EXISTS forwarding_protection_enabled BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.room_participants
  ADD COLUMN IF NOT EXISTS forwarding_protection_updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.room_participants
SET forwarding_protection_enabled = false
WHERE forwarding_protection_enabled IS NULL;

UPDATE public.room_participants
SET forwarding_protection_updated_at = now()
WHERE forwarding_protection_updated_at IS NULL;

CREATE OR REPLACE FUNCTION public.set_forwarding_protection_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.forwarding_protection_enabled IS DISTINCT FROM OLD.forwarding_protection_enabled THEN
    NEW.forwarding_protection_updated_at = now();
  ELSE
    NEW.forwarding_protection_updated_at = OLD.forwarding_protection_updated_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_participants_forwarding_protection_timestamp
  ON public.room_participants;
CREATE TRIGGER room_participants_forwarding_protection_timestamp
  BEFORE UPDATE OF forwarding_protection_enabled
  ON public.room_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_forwarding_protection_updated_at();

CREATE OR REPLACE FUNCTION public.set_room_forwarding_protection(
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
  SET forwarding_protection_enabled = p_enabled
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
  RETURNING forwarding_protection_enabled INTO updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room participant not found';
  END IF;

  RETURN updated;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_room_forwarding_protection(
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
    COALESCE(bool_or(rp.forwarding_protection_enabled), false),
    COALESCE(
      bool_or(rp.forwarding_protection_enabled)
        FILTER (WHERE rp.profile_id = auth.uid()),
      false
    ),
    COUNT(*) FILTER (WHERE rp.forwarding_protection_enabled),
    COUNT(*)::BIGINT,
    MAX(rp.forwarding_protection_updated_at)
  FROM public.room_participants rp
  WHERE rp.room_id = p_room_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_room_forwarding_protection(UUID, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_room_forwarding_protection(UUID, BOOLEAN)
  TO authenticated;

REVOKE ALL ON FUNCTION public.get_room_forwarding_protection(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_room_forwarding_protection(UUID)
  TO authenticated;
