-- 32: Fix delete chat and restore logic
-- Prevents history_cleared_at from being wiped to NULL when a deleted room is re-opened or receives a new message.
-- This ensures deleted messages NEVER reappear when searching/re-opening a contact.

-- 1. Update get_or_create_direct_room to ONLY reset deleted_at = NULL, preserving history_cleared_at
CREATE OR REPLACE FUNCTION public.get_or_create_direct_room(
  other_user_id UUID,
  requested_room_type TEXT DEFAULT 'normal',
  p_screenshot_protection BOOLEAN DEFAULT TRUE
)
RETURNS UUID AS $$
DECLARE
  current_user_id UUID := auth.uid();
  existing_room_id UUID;
  new_room_id UUID;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF other_user_id IS NULL THEN
    RAISE EXCEPTION 'Other user is required';
  END IF;

  IF current_user_id = other_user_id THEN
    RAISE EXCEPTION 'Cannot create direct room with yourself';
  END IF;

  IF requested_room_type NOT IN ('normal', 'guardian') THEN
    RAISE EXCEPTION 'Unsupported room type: %', requested_room_type;
  END IF;

  SELECT rp1.room_id
  INTO existing_room_id
  FROM public.room_participants AS rp1
  JOIN public.room_participants AS rp2
    ON rp2.room_id = rp1.room_id
  JOIN public.chat_rooms AS cr
    ON cr.id = rp1.room_id
  WHERE rp1.profile_id = current_user_id
    AND rp2.profile_id = other_user_id
    AND cr.room_type = requested_room_type
  LIMIT 1;

  IF existing_room_id IS NOT NULL THEN
    -- Restore: ONLY clear deleted_at. NEVER clear history_cleared_at!
    UPDATE public.room_participants
    SET deleted_at = NULL
    WHERE room_id = existing_room_id
      AND profile_id = current_user_id;

    RETURN existing_room_id;
  END IF;

  INSERT INTO public.chat_rooms (room_type)
  VALUES (requested_room_type)
  RETURNING id INTO new_room_id;

  INSERT INTO public.room_participants (room_id, profile_id, screenshot_protection_enabled)
  VALUES
    (new_room_id, current_user_id, p_screenshot_protection),
    (new_room_id, other_user_id, TRUE)
  ON CONFLICT DO NOTHING;

  RETURN new_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Update trigger to ONLY reset deleted_at = NULL on new message, preserving history_cleared_at
CREATE OR REPLACE FUNCTION public.handle_new_message_restore_rooms()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.room_participants
  SET deleted_at = NULL
  WHERE room_id = NEW.room_id
    AND deleted_at IS NOT NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
