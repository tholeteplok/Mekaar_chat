-- 38_fix_room_participant_rpcs.sql
-- Fix: RPC di migration 24 pakai kolom 'user_id' yang tidak ada.
-- Tabel room_participants pakai 'profile_id' (migration 01).
-- Ini menyebabkan set_room_disappearing_override, toggle_room_mute,
-- dan mute_room_for_hours selalu gagal secara diam-diam.

BEGIN;

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
    AND profile_id = auth.uid();
END;
$$;

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
        WHEN p_hours = 0 THEN NULL
        ELSE NOW() + (p_hours || ' hours')::INTERVAL
      END
  WHERE room_id = p_room_id
    AND profile_id = auth.uid();
END;
$$;

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
    AND profile_id = auth.uid();
END;
$$;

COMMIT;
