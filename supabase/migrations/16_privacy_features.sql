-- Migration 16: Privacy controls (Telegram-style)
-- Additive only - safe to run on existing databases.
-- 1) last_seen_privacy + read_receipts_enabled on profiles
-- 2) user_blocks table (user-to-user block list)
-- 3) update public_profiles view to expose last_seen_privacy
-- 4) RPCs: get_last_seen_for (honors privacy), is_blocked_by_me

-- ─────────────────────────────────────────
-- 1. Presence privacy preferences
-- ─────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_seen_privacy TEXT NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS read_receipts_enabled BOOLEAN NOT NULL DEFAULT true;

-- ─────────────────────────────────────────
-- 2. User block list
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks (blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks (blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_blocks_select_own" ON public.user_blocks;
CREATE POLICY "user_blocks_select_own" ON public.user_blocks
  FOR SELECT USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "user_blocks_insert_own" ON public.user_blocks;
CREATE POLICY "user_blocks_insert_own" ON public.user_blocks
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "user_blocks_delete_own" ON public.user_blocks;
CREATE POLICY "user_blocks_delete_own" ON public.user_blocks
  FOR DELETE USING (auth.uid() = blocker_id);

-- ─────────────────────────────────────────
-- 3. Update public_profiles view
-- ─────────────────────────────────────────
DROP VIEW IF EXISTS public.public_profiles;

CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  avatar_url,
  last_seen_at,
  last_seen_privacy,
  created_at
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;

-- ─────────────────────────────────────────
-- 4a. RPC: get_last_seen_for (honors privacy)
-- Returns last_seen_at only if the target allows it for the caller.
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_last_seen_for(target_id UUID)
RETURNS TIMESTAMPTZ AS $$
DECLARE
  v_privacy TEXT;
  v_last_seen TIMESTAMPTZ;
  v_is_contact BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  IF target_id = auth.uid() THEN
    SELECT last_seen_at INTO v_last_seen FROM public.profiles WHERE id = target_id;
    RETURN v_last_seen;
  END IF;

  SELECT last_seen_privacy, last_seen_at
    INTO v_privacy, v_last_seen
  FROM public.profiles WHERE id = target_id;

  IF v_privacy IS NULL OR v_privacy = 'everyone' THEN
    RETURN v_last_seen;
  END IF;

  -- 'contacts': allow only if a room exists between caller and target
  IF v_privacy = 'contacts' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.room_participants rp1
      JOIN public.room_participants rp2
        ON rp1.room_id = rp2.room_id
      WHERE rp1.profile_id = auth.uid()
        AND rp2.profile_id = target_id
    ) INTO v_is_contact;
    IF v_is_contact THEN RETURN v_last_seen; END IF;
  END IF;

  -- 'nobody' or non-contact contact-mode → hide
  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.get_last_seen_for(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_last_seen_for(UUID) TO authenticated;

-- ─────────────────────────────────────────
-- 4b. RPC: is_blocked_by_me(blocked_id)
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_blocked_by_me(blocked_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN FALSE; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE blocker_id = auth.uid() AND blocked_id = $1
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.is_blocked_by_me(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_blocked_by_me(UUID) TO authenticated;
