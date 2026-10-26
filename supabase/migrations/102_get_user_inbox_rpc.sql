-- ==============================================================================
-- 102_get_user_inbox_rpc.sql
-- Konsolidasi Query Obrolan: Mengeliminasi N+1 remote query di ChatRepository.getRooms()
-- Mengembalikan seluruh metadata inbox aktif pengguna dalam 1 HTTP round-trip tunggal.
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_user_inbox(p_user_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
BEGIN
    -- Ambil user ID dari session auth atau parameter
    v_user_id := COALESCE(p_user_id, auth.uid());
    
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
            cr.avatar_url AS group_avatar_url
        FROM room_participants rp
        JOIN chat_rooms cr ON cr.id = rp.room_id
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
        JOIN room_participants other_rp 
            ON other_rp.room_id = mr.room_id 
           AND other_rp.profile_id != v_user_id
        JOIN public_profiles p 
            ON p.id = other_rp.profile_id
        WHERE mr.room_type != 'group'
    ),
    group_member_counts AS (
        SELECT 
            mr.room_id,
            COUNT(DISTINCT grp.profile_id)::INT AS member_count
        FROM my_rooms mr
        JOIN room_participants grp 
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
        JOIN messages m 
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
        JOIN messages m 
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
                        'msgType', lm.msg_type,
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
    ) INTO v_result
    FROM my_rooms mr
    LEFT JOIN direct_counterparts dc ON dc.room_id = mr.room_id
    LEFT JOIN group_member_counts gmc ON gmc.room_id = mr.room_id
    LEFT JOIN unread_counts uc ON uc.room_id = mr.room_id
    LEFT JOIN last_messages lm ON lm.room_id = mr.room_id;

    RETURN v_result;
END;
$$;

-- Berikan izin eksekusi kepada authenticated user
GRANT EXECUTE ON FUNCTION get_user_inbox(UUID) TO authenticated;
