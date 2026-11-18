-- ==============================================================================
-- 117_add_group_e2ee_and_identity_signatures.sql
-- Fase 2: E2EE Obrolan Grup via Signal Sender Keys (Dart Murni)
--
-- 1. Tambah kolom ed25519_identity_key pada tabel profiles (untuk verifikasi tanda tangan SKDM dan pesan grup).
-- 2. Tambah kolom encryption_version pada tabel chat_rooms (0 = legacy TLS+RLS, 1 = Signal Sender Keys E2EE).
-- 3. Perbarui view public_profiles agar menyertakan ed25519_identity_key (security_invoker = true).
-- 4. Perbarui RPC create_group_room agar grup baru otomatis dibuat dengan encryption_version = 1.
-- 5. Tambah RPC upgrade_group_encryption_version(p_room_id UUID) khusus Owner/Admin grup lama.
-- 6. Perbarui RPC get_user_inbox() agar mengembalikan encryptionVersion ke klien.
-- ==============================================================================

-- 1. Tambah kolom ed25519_identity_key di public.profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS ed25519_identity_key TEXT;

-- 2. Tambah kolom encryption_version di public.chat_rooms
ALTER TABLE public.chat_rooms 
  ADD COLUMN IF NOT EXISTS encryption_version INTEGER NOT NULL DEFAULT 0;

-- 3. Perbarui view public.public_profiles beserta view dependennya (public.user_contacts_view)
DROP VIEW IF EXISTS public.user_contacts_view;
DROP VIEW IF EXISTS public.public_profiles CASCADE;

CREATE VIEW public.public_profiles
WITH (security_invoker = true, security_barrier = true)
AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  CASE
    WHEN last_seen_privacy = 'nobody' THEN NULL::TIMESTAMPTZ
    ELSE last_seen_at
  END AS last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key,
  chat_invitation_mode,
  bio,
  ed25519_identity_key
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;
REVOKE ALL ON public.public_profiles FROM anon;

-- Recreate public.user_contacts_view yang bergantung pada public.public_profiles
CREATE VIEW public.user_contacts_view
WITH (security_invoker = true, security_barrier = true)
AS
SELECT
  c.id,
  c.user_id,
  c.contact_user_id,
  c.alias_name,
  c.is_vaulted,
  c.vault_slot,
  c.created_at,
  p.username,
  p.full_name,
  p.display_name,
  p.avatar_url,
  p.bio,
  EXISTS (
    SELECT 1 FROM public.guardians g
    WHERE (g.owner_id = c.user_id AND g.guardian_id = c.contact_user_id AND g.status = 'active')
       OR (g.guardian_id = c.user_id AND g.owner_id = c.contact_user_id AND g.status = 'active')
  ) AS is_guardian
FROM public.user_contacts c
JOIN public.public_profiles p ON p.id = c.contact_user_id;

GRANT SELECT ON public.user_contacts_view TO authenticated;
REVOKE ALL ON public.user_contacts_view FROM anon;

-- 4. Perbarui create_group_room agar grup baru default ke encryption_version = 1
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
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Group name is required' USING ERRCODE = '22023';
  END IF;

  -- Create chat_room of type 'group' dengan encryption_version = 1 (E2EE Signal Sender Keys)
  INSERT INTO public.chat_rooms (room_type, name, avatar_url, description, created_by, encryption_version)
  VALUES ('group', trim(p_name), p_avatar_url, p_description, v_current_user_id, 1)
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

REVOKE EXECUTE ON FUNCTION public.create_group_room(TEXT, TEXT, TEXT, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_group_room(TEXT, TEXT, TEXT, UUID[]) TO authenticated;

-- 5. Tambah RPC upgrade_group_encryption_version(p_room_id UUID)
CREATE OR REPLACE FUNCTION public.upgrade_group_encryption_version(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_current_version INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Tidak terotentikasi' USING ERRCODE = '42501';
  END IF;

  -- Cek role pemanggil di grup
  SELECT role INTO v_role
  FROM public.room_participants
  WHERE room_id = p_room_id
    AND profile_id = v_user_id
    AND deleted_at IS NULL;

  IF v_role IS NULL OR v_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Hanya Admin atau Pemilik grup yang dapat meningkatkan enkripsi grup' USING ERRCODE = '42501';
  END IF;

  SELECT encryption_version INTO v_current_version
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_current_version >= 1 THEN
    RETURN jsonb_build_object(
      'success', true, 
      'encryption_version', v_current_version, 
      'message', 'Grup sudah berada pada versi E2EE'
    );
  END IF;

  UPDATE public.chat_rooms
  SET encryption_version = 1,
      updated_at = NOW()
  WHERE id = p_room_id;

  RETURN jsonb_build_object(
    'success', true, 
    'encryption_version', 1, 
    'message', 'Grup berhasil ditingkatkan ke E2EE Signal Sender Keys'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.upgrade_group_encryption_version(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upgrade_group_encryption_version(UUID) TO authenticated;

-- 6. Perbarui get_user_inbox() untuk menyertakan encryption_version
CREATE OR REPLACE FUNCTION public.get_user_inbox()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    WITH my_rooms AS (
        SELECT 
            rp.room_id,
            rp.is_muted,
            rp.is_archived,
            rp.last_read_at,
            rp.history_cleared_at,
            cr.room_type,
            cr.name AS group_name,
            cr.avatar_url AS group_avatar_url,
            COALESCE(cr.encryption_version, 0) AS encryption_version
        FROM public.room_participants rp
        JOIN public.chat_rooms cr ON cr.id = rp.room_id
        WHERE rp.profile_id = v_user_id
          AND rp.deleted_at IS NULL
    ),
    direct_counterparts AS (
        SELECT 
            mr.room_id,
            p.id AS other_user_id,
            p.username,
            p.full_name,
            p.display_name,
            p.avatar_url
        FROM my_rooms mr
        JOIN public.room_participants other_rp 
            ON other_rp.room_id = mr.room_id 
           AND other_rp.profile_id != v_user_id
        JOIN public.public_profiles p 
            ON p.id = other_rp.profile_id
        WHERE mr.room_type != 'group'
    ),
    group_member_counts AS (
        SELECT 
            mr.room_id,
            COUNT(DISTINCT grp.profile_id)::INT AS member_count
        FROM my_rooms mr
        JOIN public.room_participants grp 
            ON grp.room_id = mr.room_id 
           AND grp.deleted_at IS NULL
        WHERE mr.room_type = 'group'
        GROUP BY mr.room_id
    ),
    unread_counts AS (
        SELECT 
            mr.room_id,
            COUNT(m.id)::INT AS unread_count
        FROM my_rooms mr
        JOIN public.messages m 
            ON m.room_id = mr.room_id
           AND m.sender_id != v_user_id
           AND m.is_deleted = FALSE
           AND (mr.last_read_at IS NULL OR m.created_at > mr.last_read_at)
           AND (mr.history_cleared_at IS NULL OR m.created_at > mr.history_cleared_at)
        GROUP BY mr.room_id
    ),
    last_messages AS (
        SELECT DISTINCT ON (m.room_id)
            mr.room_id,
            m.id AS message_id,
            m.sender_id,
            m.content,
            m.media_url,
            m.msg_type,
            m.is_view_once,
            m.is_opened,
            m.opened_at,
            m.reply_to_id,
            m.is_encrypted,
            m.created_at,
            m.updated_at
        FROM my_rooms mr
        JOIN public.messages m 
            ON m.room_id = mr.room_id
           AND m.is_deleted = FALSE
           AND m.is_silent_deleted = FALSE
           AND (mr.history_cleared_at IS NULL OR m.created_at > mr.history_cleared_at)
        ORDER BY m.room_id, m.created_at DESC
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', mr.room_id,
                'roomType', mr.room_type,
                'isGroup', (mr.room_type = 'group'),
                'isGuardian', (mr.room_type = 'guardian'),
                'isMuted', COALESCE(mr.is_muted, FALSE),
                'isArchived', COALESCE(mr.is_archived, FALSE),
                'encryptionVersion', mr.encryption_version,
                'otherUserId', CASE 
                    WHEN mr.room_type = 'group' THEN v_user_id::TEXT
                    ELSE COALESCE(dc.other_user_id::TEXT, v_user_id::TEXT)
                END,
                'name', CASE 
                    WHEN mr.room_type = 'group' THEN 
                        COALESCE(NULLIF(mr.group_name, ''), 'Grup Mekaar')
                    ELSE 
                        COALESCE(NULLIF(dc.display_name, ''), NULLIF(dc.full_name, ''), NULLIF(dc.username, ''), 'User')
                END,
                'avatar', CASE 
                    WHEN mr.room_type = 'group' THEN 
                        UPPER(SUBSTRING(COALESCE(NULLIF(mr.group_name, ''), 'G'), 1, 1))
                    ELSE 
                        UPPER(SUBSTRING(COALESCE(NULLIF(dc.display_name, ''), NULLIF(dc.full_name, ''), NULLIF(dc.username, ''), 'U'), 1, 1))
                END,
                'avatarUrl', CASE 
                    WHEN mr.room_type = 'group' THEN mr.group_avatar_url
                    ELSE dc.avatar_url
                END,
                'memberCount', COALESCE(gmc.member_count, 0),
                'unreadCount', COALESCE(uc.unread_count, 0),
                'timestamp', lm.created_at,
                'lastMessage', CASE 
                    WHEN lm.message_id IS NOT NULL THEN jsonb_build_object(
                        'id', lm.message_id,
                        'roomId', lm.room_id,
                        'senderId', lm.sender_id,
                        'content', lm.content,
                        'mediaUrl', lm.media_url,
                        'type', lm.msg_type,
                        'isViewOnce', lm.is_view_once,
                        'isOpened', lm.is_opened,
                        'openedAt', lm.opened_at,
                        'replyToId', lm.reply_to_id,
                        'isEncrypted', lm.is_encrypted,
                        'createdAt', lm.created_at,
                        'updatedAt', lm.updated_at
                    )
                    ELSE NULL
                END
            )
            ORDER BY COALESCE(lm.created_at, '1970-01-01'::TIMESTAMPTZ) DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM my_rooms mr
    LEFT JOIN direct_counterparts dc ON dc.room_id = mr.room_id
    LEFT JOIN group_member_counts gmc ON gmc.room_id = mr.room_id
    LEFT JOIN unread_counts uc ON uc.room_id = mr.room_id
    LEFT JOIN last_messages lm ON lm.room_id = mr.room_id;

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_inbox() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_inbox() TO authenticated;
