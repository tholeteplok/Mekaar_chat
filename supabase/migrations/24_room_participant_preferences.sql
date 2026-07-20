-- 24_room_participant_preferences.sql
-- Per-contact/room privacy settings: mute, disappearing override, archive

BEGIN;

ALTER TABLE room_participants
  ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS muted_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS disappearing_override_hours INTEGER, -- NULL = gunakan global default
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE;

-- RPC: toggle mute untuk room tertentu
CREATE OR REPLACE FUNCTION toggle_room_mute(p_room_id UUID, p_muted BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE room_participants
  SET is_muted = p_muted,
      muted_until = CASE WHEN p_muted THEN NULL ELSE muted_until END
  WHERE room_id = p_room_id
    AND user_id = auth.uid();
END;
$$;

-- RPC: set mute dengan durasi (jam)
CREATE OR REPLACE FUNCTION mute_room_for_hours(p_room_id UUID, p_hours INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE room_participants
  SET is_muted = TRUE,
      muted_until = CASE
        WHEN p_hours = 0 THEN NULL -- selamanya
        ELSE NOW() + (p_hours || ' hours')::INTERVAL
      END
  WHERE room_id = p_room_id
    AND user_id = auth.uid();
END;
$$;

-- RPC: set disappearing message override untuk room tertentu
CREATE OR REPLACE FUNCTION set_room_disappearing_override(p_room_id UUID, p_hours INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_hours < 0 THEN
    RAISE EXCEPTION 'disappearing hours tidak boleh negatif';
  END IF;

  UPDATE room_participants
  SET disappearing_override_hours = NULLIF(p_hours, 0)
  WHERE room_id = p_room_id
    AND user_id = auth.uid();
END;
$$;

COMMIT;
