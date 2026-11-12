-- 115: Group Governance, Permissions, and Management RPCs
-- Provides comprehensive administrative control, role hierarchy, announcement mode, and ownership transfer.

-- 1. Extend chat_rooms with group governance columns
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS is_announcement_only BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS members_can_edit_info BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.chat_rooms ADD COLUMN IF NOT EXISTS members_can_invite BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Guard: Prevent non-admin message insertion in announcement-only groups
CREATE OR REPLACE FUNCTION public.guard_announcement_mode_messages()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_announcement BOOLEAN := FALSE;
  v_sender_role TEXT;
BEGIN
  SELECT is_announcement_only INTO v_is_announcement
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  IF v_is_announcement IS TRUE THEN
    SELECT role INTO v_sender_role
    FROM public.room_participants
    WHERE room_id = NEW.room_id
      AND profile_id = NEW.sender_id
      AND deleted_at IS NULL;

    IF v_sender_role IS NULL OR v_sender_role NOT IN ('owner', 'admin') THEN
      RAISE EXCEPTION 'Hanya admin yang dapat mengirim pesan pada grup mode siaran.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_announcement_mode_messages ON public.messages;
CREATE TRIGGER trg_guard_announcement_mode_messages
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_announcement_mode_messages();

-- 3. RPC: Promote group admin (Owner only)
CREATE OR REPLACE FUNCTION public.promote_group_admin(
  p_room_id UUID,
  p_target_profile_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik grup yang dapat mengangkat admin.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.room_participants
  SET role = 'admin'
  WHERE room_id = p_room_id
    AND profile_id = p_target_profile_id
    AND deleted_at IS NULL;
END;
$$;

-- 4. RPC: Demote group admin (Owner only)
CREATE OR REPLACE FUNCTION public.demote_group_admin(
  p_room_id UUID,
  p_target_profile_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik grup yang dapat mencabut hak admin.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.room_participants
  SET role = 'member'
  WHERE room_id = p_room_id
    AND profile_id = p_target_profile_id
    AND deleted_at IS NULL;
END;
$$;

-- 5. RPC: Transfer group ownership (Owner only)
CREATE OR REPLACE FUNCTION public.transfer_group_ownership(
  p_room_id UUID,
  p_new_owner_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_target_exists BOOLEAN;
BEGIN
  IF p_new_owner_id = auth.uid() THEN
    RETURN;
  END IF;

  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik grup yang dapat mengalihkan kepemilikan.'
      USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = p_new_owner_id
      AND deleted_at IS NULL
  ) INTO v_target_exists;

  IF NOT v_target_exists THEN
    RAISE EXCEPTION 'Peserta tujuan tidak ditemukan atau sudah keluar dari grup.'
      USING ERRCODE = 'P0002';
  END IF;

  -- Demote current owner to admin
  UPDATE public.room_participants
  SET role = 'admin'
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  -- Elevate new owner to owner
  UPDATE public.room_participants
  SET role = 'owner'
  WHERE room_id = p_room_id
    AND profile_id = p_new_owner_id
    AND deleted_at IS NULL;

  -- Update created_by in chat_rooms
  UPDATE public.chat_rooms
  SET created_by = p_new_owner_id
  WHERE id = p_room_id;
END;
$$;

-- 6. RPC: Remove group member (Owner or Admin)
CREATE OR REPLACE FUNCTION public.remove_group_member(
  p_room_id UUID,
  p_target_profile_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_target_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya admin atau pemilik yang dapat mengeluarkan anggota.'
      USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_target_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = p_target_profile_id
    AND deleted_at IS NULL;

  IF v_target_role = 'owner' THEN
    RAISE EXCEPTION 'Pemilik grup tidak dapat dikeluarkan.'
      USING ERRCODE = '42501';
  END IF;

  IF v_caller_role = 'admin' AND v_target_role = 'admin' THEN
    RAISE EXCEPTION 'Admin tidak dapat mengeluarkan sesama admin.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.room_participants
  SET deleted_at = NOW()
  WHERE room_id = p_room_id
    AND profile_id = p_target_profile_id
    AND deleted_at IS NULL;
END;
$$;

-- 7. RPC: Leave group (With owner transfer requirement)
CREATE OR REPLACE FUNCTION public.leave_group(
  p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_other_members_count INT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role IS NULL THEN
    RETURN;
  END IF;

  IF v_caller_role = 'owner' THEN
    SELECT COUNT(*) INTO v_other_members_count
    FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id != auth.uid()
      AND deleted_at IS NULL;

    IF v_other_members_count > 0 THEN
      RAISE EXCEPTION 'Pemilik grup wajib mengalihkan kepemilikan sebelum keluar dari grup.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.room_participants
  SET deleted_at = NOW()
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$;

-- 8. RPC: Update group info (Name, Description, Avatar)
CREATE OR REPLACE FUNCTION public.update_group_info(
  p_room_id UUID,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_members_can_edit BOOLEAN;
BEGIN
  SELECT rp.role, cr.members_can_edit_info
  INTO v_caller_role, v_members_can_edit
  FROM public.room_participants rp
  JOIN public.chat_rooms cr ON cr.id = rp.room_id
  WHERE rp.room_id = p_room_id
    AND rp.profile_id = auth.uid()
    AND rp.deleted_at IS NULL;

  IF v_caller_role NOT IN ('owner', 'admin') AND v_members_can_edit IS NOT TRUE THEN
    RAISE EXCEPTION 'Akses ditolak: Anda tidak memiliki izin untuk mengubah info grup.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.chat_rooms
  SET
    name = CASE WHEN p_name IS NOT NULL AND trim(p_name) <> '' THEN trim(p_name) ELSE name END,
    description = COALESCE(p_description, description),
    avatar_url = COALESCE(p_avatar_url, avatar_url)
  WHERE id = p_room_id;
END;
$$;

-- 9. RPC: Update group permissions (Announcement mode & edit/invite flags)
CREATE OR REPLACE FUNCTION public.update_group_permissions(
  p_room_id UUID,
  p_is_announcement_only BOOLEAN,
  p_members_can_edit_info BOOLEAN,
  p_members_can_invite BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya admin atau pemilik yang dapat mengatur izin grup.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.chat_rooms
  SET
    is_announcement_only = p_is_announcement_only,
    members_can_edit_info = p_members_can_edit_info,
    members_can_invite = p_members_can_invite
  WHERE id = p_room_id;
END;
$$;

-- 10. RPC: Disband group (Owner only)
CREATE OR REPLACE FUNCTION public.disband_group(
  p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
    AND deleted_at IS NULL;

  IF v_caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik grup yang dapat membubarkan grup.'
      USING ERRCODE = '42501';
  END IF;

  -- Soft delete all participants
  UPDATE public.room_participants
  SET deleted_at = NOW()
  WHERE room_id = p_room_id
    AND deleted_at IS NULL;

  -- Mark group room title as disbanded
  UPDATE public.chat_rooms
  SET name = '[Dibubarkan] ' || COALESCE(name, 'Grup')
  WHERE id = p_room_id;
END;
$$;

-- 11. Grant EXECUTE permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.promote_group_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.demote_group_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_group_ownership(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_group_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_group(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_group_info(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_group_permissions(UUID, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.disband_group(UUID) TO authenticated;
