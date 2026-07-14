-- Security + data integrity hardening for MVP.
-- Additive migration: avoids rewriting earlier migrations while tightening runtime access.

-- -----------------------------------------------------------------------------
-- Public profile search surface
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  avatar_url,
  created_at
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.search_public_profiles(search_query TEXT)
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  avatar_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.username,
    p.full_name,
    p.avatar_url
  FROM public.profiles AS p
  WHERE
    auth.uid() IS NOT NULL
    AND search_query IS NOT NULL
    AND length(trim(search_query)) >= 2
    AND (
      p.username = trim(search_query)
      OR p.email = trim(search_query)
    )
  ORDER BY p.username ASC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.search_public_profiles(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- Room helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_room_participant(room_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  IF room_uuid IS NULL OR user_uuid IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.room_participants AS rp
    WHERE rp.room_id = room_uuid
      AND rp.profile_id = user_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_or_create_direct_room(
  other_user_id UUID,
  requested_room_type TEXT DEFAULT 'normal'
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
    RETURN existing_room_id;
  END IF;

  INSERT INTO public.chat_rooms (room_type)
  VALUES (requested_room_type)
  RETURNING id INTO new_room_id;

  INSERT INTO public.room_participants (room_id, profile_id)
  VALUES
    (new_room_id, current_user_id),
    (new_room_id, other_user_id)
  ON CONFLICT DO NOTHING;

  RETURN new_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.get_or_create_direct_room(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_room(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_room_read(room_uuid UUID)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.room_participants
  SET last_read_at = now()
  WHERE room_id = room_uuid
    AND profile_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.mark_room_read(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_room_read(UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- Evidence-preserving message deletion
-- -----------------------------------------------------------------------------

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.soft_delete_message(message_uuid UUID)
RETURNS VOID AS $$
DECLARE
  target_message public.messages%ROWTYPE;
  target_room_type TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT *
  INTO target_message
  FROM public.messages
  WHERE id = message_uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF target_message.sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only sender can delete this message';
  END IF;

  SELECT room_type
  INTO target_room_type
  FROM public.chat_rooms
  WHERE id = target_message.room_id;

  IF target_room_type = 'guardian' THEN
    INSERT INTO public.security_logs (user_id, event_type, details)
    VALUES (
      auth.uid(),
      'guardian_message_soft_deleted',
      jsonb_build_object(
        'message_id', target_message.id,
        'room_id', target_message.room_id,
        'sender_id', target_message.sender_id,
        'content_snapshot', target_message.content,
        'message_type', target_message.msg_type,
        'created_at', target_message.created_at,
        'deleted_at', now()
      )
    );
  END IF;

  UPDATE public.messages
  SET
    is_deleted = TRUE,
    deleted_at = COALESCE(deleted_at, now()),
    updated_at = now(),
    content = CASE
      WHEN target_room_type = 'guardian' THEN '[Pesan dihapus - bukti tersimpan]'
      ELSE ''
    END,
    media_url = NULL
  WHERE id = message_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.soft_delete_message(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.soft_delete_message(UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- Tighten policies that previously exposed broad profile/message access.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can search other profiles" ON public.profiles;

DROP POLICY IF EXISTS "Users can read/write messages in their rooms" ON public.messages;
CREATE POLICY "Participants can read messages" ON public.messages
  FOR SELECT USING (public.is_room_participant(room_id, auth.uid()));
CREATE POLICY "Participants can send own messages" ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND public.is_room_participant(room_id, auth.uid())
  );
CREATE POLICY "Senders can soft update own messages" ON public.messages
  FOR UPDATE USING (
    sender_id = auth.uid()
    AND public.is_room_participant(room_id, auth.uid())
  ) WITH CHECK (
    sender_id = auth.uid()
    AND public.is_room_participant(room_id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert room participants" ON public.room_participants;
CREATE POLICY "Authenticated users can insert room participants" ON public.room_participants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert chat rooms" ON public.chat_rooms;
CREATE POLICY "Authenticated users can insert chat rooms" ON public.chat_rooms
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
