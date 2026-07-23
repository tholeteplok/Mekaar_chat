-- 33: Add Group Chat Support (>2 Users)
-- Extends chat_rooms and room_participants to support group chats, roles, group metadata, and RPC create_group_room.

-- 1. Update room_type CHECK constraint on chat_rooms
ALTER TABLE public.chat_rooms DROP CONSTRAINT IF EXISTS chat_rooms_room_type_check;
ALTER TABLE public.chat_rooms ADD CONSTRAINT chat_rooms_room_type_check 
  CHECK (room_type IN ('normal', 'guardian', 'self_device', 'group'));

-- 2. Add group metadata columns to chat_rooms
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id);

-- 3. Add role and invited_by columns to room_participants
ALTER TABLE public.room_participants ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member';
ALTER TABLE public.room_participants DROP CONSTRAINT IF EXISTS room_participants_role_check;
ALTER TABLE public.room_participants ADD CONSTRAINT room_participants_role_check 
  CHECK (role IN ('owner', 'admin', 'member'));
ALTER TABLE public.room_participants ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES public.profiles(id);

-- 4. RPC function to create a group chat atomically
CREATE OR REPLACE FUNCTION public.create_group_room(
  p_name TEXT,
  p_avatar_url TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_participant_ids UUID[] DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  v_current_user_id UUID := auth.uid();
  v_room_id UUID;
  v_pid UUID;
BEGIN
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Group name is required';
  END IF;

  -- Create chat_room of type 'group'
  INSERT INTO public.chat_rooms (room_type, name, avatar_url, description, created_by)
  VALUES ('group', trim(p_name), p_avatar_url, p_description, v_current_user_id)
  RETURNING id INTO v_room_id;

  -- Insert current user as owner
  INSERT INTO public.room_participants (room_id, profile_id, role, screenshot_protection_enabled)
  VALUES (v_room_id, v_current_user_id, 'owner', TRUE)
  ON CONFLICT (room_id, profile_id) DO UPDATE SET role = 'owner';

  -- Insert remaining participants as member
  IF p_participant_ids IS NOT NULL THEN
    FOREACH v_pid IN ARRAY p_participant_ids LOOP
      IF v_pid IS NOT NULL AND v_pid <> v_current_user_id THEN
        INSERT INTO public.room_participants (room_id, profile_id, role, invited_by, screenshot_protection_enabled)
        VALUES (v_room_id, v_pid, 'member', v_current_user_id, TRUE)
        ON CONFLICT (room_id, profile_id) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN v_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.create_group_room TO authenticated;
