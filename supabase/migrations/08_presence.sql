-- Migration 08: Presence, Reactions, and Message Edit tracking
-- Additive only - safe to run on existing databases

-- ─────────────────────────────────────────
-- 1. User presence tracking (last seen)
-- ─────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- Function to update last_seen_at (called from client on every authenticated action)
CREATE OR REPLACE FUNCTION public.update_last_seen()
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  UPDATE public.profiles
  SET last_seen_at = now()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.update_last_seen() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_last_seen() TO authenticated;

-- ─────────────────────────────────────────
-- 2. Message reactions (JSONB map of emoji → array of user_ids)
-- Example: {"👍": ["uuid1", "uuid2"], "❤️": ["uuid3"]}
-- ─────────────────────────────────────────
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reactions JSONB NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_messages_reactions ON public.messages USING GIN(reactions);

-- ─────────────────────────────────────────
-- 3. Update public_profiles view to include last_seen_at
-- ─────────────────────────────────────────
DROP VIEW IF EXISTS public.public_profiles;

CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  avatar_url,
  last_seen_at,
  created_at
FROM public.profiles;


GRANT SELECT ON public.public_profiles TO authenticated;

-- ─────────────────────────────────────────
-- 4. RPC: toggle_reaction - atomically add or remove a reaction
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_reaction(message_uuid UUID, emoji_key TEXT)
RETURNS JSONB AS $$
DECLARE
  current_user_id UUID := auth.uid();
  current_reactions JSONB;
  current_users JSONB;
  new_users JSONB;
  new_reactions JSONB;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT reactions INTO current_reactions
  FROM public.messages
  WHERE id = message_uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  current_users := COALESCE(current_reactions -> emoji_key, '[]'::JSONB);

  -- Toggle: if user already reacted, remove; otherwise add
  IF current_users @> to_jsonb(current_user_id::TEXT) THEN
    SELECT jsonb_agg(val)
    INTO new_users
    FROM jsonb_array_elements_text(current_users) AS val
    WHERE val <> current_user_id::TEXT;
    new_users := COALESCE(new_users, '[]'::JSONB);
  ELSE
    new_users := current_users || to_jsonb(current_user_id::TEXT);
  END IF;

  -- If empty array, remove the key entirely
  IF jsonb_array_length(new_users) = 0 THEN
    new_reactions := current_reactions - emoji_key;
  ELSE
    new_reactions := jsonb_set(current_reactions, ARRAY[emoji_key], new_users);
  END IF;

  UPDATE public.messages
  SET reactions = new_reactions, updated_at = now()
  WHERE id = message_uuid;

  RETURN new_reactions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.toggle_reaction(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.toggle_reaction(UUID, TEXT) TO authenticated;
