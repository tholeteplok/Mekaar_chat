-- ==============================================================================
-- Migration: 31_advanced_delete.sql
-- Description: Implement "silent delete" (Telegram-like unread cancel) and
--              "hide for me" (WhatsApp-like local tombstone delete) features.
-- ==============================================================================

-- 1. Add `is_silent_deleted` to messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_silent_deleted BOOLEAN DEFAULT false;

-- 2. Create `hidden_messages` table for "Hapus untuk Saya" (Delete for Me)
CREATE TABLE IF NOT EXISTS public.hidden_messages (
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    hidden_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (profile_id, message_id)
);

-- Enable RLS on hidden_messages
ALTER TABLE public.hidden_messages ENABLE ROW LEVEL SECURITY;

-- Policy: User can only see and manage their own hidden messages
CREATE POLICY "Users can manage their own hidden messages"
ON public.hidden_messages
FOR ALL USING (profile_id = auth.uid());

-- Grant privileges
GRANT ALL ON TABLE public.hidden_messages TO authenticated;

-- 3. RPC for "Delete for Everyone" (with Telegram-like silent delete logic)
CREATE OR REPLACE FUNCTION public.delete_message_for_everyone(msg_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    msg_room_id UUID;
    msg_sender_id UUID;
    msg_created_at TIMESTAMPTZ;
    room_is_guardian BOOLEAN;
    other_last_read TIMESTAMPTZ;
BEGIN
    -- 1. Fetch message details and ensure it belongs to the caller
    SELECT room_id, sender_id, created_at 
    INTO msg_room_id, msg_sender_id, msg_created_at
    FROM public.messages
    WHERE id = msg_uuid;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Only the sender can delete their own message (or admins, but let's stick to sender)
    IF msg_sender_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to delete this message';
    END IF;

    -- 2. Check room type (is it a guardian room or general?)
    SELECT (room_type = 'guardian') INTO room_is_guardian
    FROM public.chat_rooms
    WHERE id = msg_room_id;

    -- 3. Check if the message has been read by the OTHER participant
    -- We get the MAX last_read_at of all OTHER participants in the room.
    SELECT MAX(last_read_at) INTO other_last_read
    FROM public.room_participants
    WHERE room_id = msg_room_id
      AND profile_id != auth.uid();

    -- 4. Determine deletion type
    IF room_is_guardian THEN
        -- Guardian rooms ALWAYS leave a tombstone (compliance requirement)
        UPDATE public.messages
        SET is_deleted = true,
            deleted_at = now(),
            updated_at = now()
        WHERE id = msg_uuid;
    ELSE
        -- General chat: if unread (created AFTER the other person's last read time)
        -- AND they haven't read it yet (meaning their last_read_at is before message creation
        -- or they have never read anything i.e. last_read_at IS NULL).
        IF other_last_read IS NULL OR msg_created_at > other_last_read THEN
            -- Unread: SILENT DELETE (disappears completely without tombstone)
            UPDATE public.messages
            SET is_silent_deleted = true,
                is_deleted = true, -- Also set global deleted flag just in case
                deleted_at = now(),
                updated_at = now()
            WHERE id = msg_uuid;
        ELSE
            -- Read: Standard soft delete (leaves tombstone)
            UPDATE public.messages
            SET is_deleted = true,
                deleted_at = now(),
                updated_at = now()
            WHERE id = msg_uuid;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. RPC for "Hide for Me" (WhatsApp-like local delete)
CREATE OR REPLACE FUNCTION public.hide_message_for_me(msg_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if user is a participant of the room the message belongs to
    IF NOT EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.room_participants rp ON m.room_id = rp.room_id
        WHERE m.id = msg_uuid AND rp.profile_id = auth.uid()
    ) THEN
        RETURN FALSE;
    END IF;

    -- Insert into hidden_messages (ignore if already hidden)
    INSERT INTO public.hidden_messages (profile_id, message_id)
    VALUES (auth.uid(), msg_uuid)
    ON CONFLICT (profile_id, message_id) DO NOTHING;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
