-- ============================================================================
-- MEKAAR 3.0 Migration 83: Admin Legal Hold RPC & Data Retention Guard
-- ============================================================================
-- 1. Menambahkan Stored Procedure admin_set_legal_hold
-- 2. Mengintegrasikan proteksi legal_hold_active ke seluruh jalur penghapusan:
--    - purge_expired_messages (disappearing messages & scheduled wipe)
--    - execute_room_scheduled_wipe (pembersihan room terjadwal)
--    - execute_room_burn_on_exit (burn on exit)
--    - delete_message_for_everyone (hapus untuk semua orang)
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. RPC Moderasi Admin: Set Legal Hold (dengan Admin Guard & Audit Log)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_legal_hold(
  p_target_user_id uuid,
  p_active boolean,
  p_case_ref text DEFAULT NULL,
  p_admin_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
  v_action text;
BEGIN
  v_admin_id := COALESCE(p_admin_id, auth.uid());

  -- IMPERATIVE GUARD: Verifikasi Role Admin
  SELECT is_admin INTO v_is_admin
  FROM public.profiles
  WHERE id = v_admin_id;

  IF COALESCE(v_is_admin, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'FORBIDDEN: Hanya administrator terautentikasi yang dapat mengatur status Legal Hold.';
  END IF;

  -- Update status legal hold pada profiles
  UPDATE public.profiles
  SET legal_hold_active = p_active,
      legal_hold_case_ref = CASE WHEN p_active THEN p_case_ref ELSE NULL END
  WHERE id = p_target_user_id;

  v_action := CASE WHEN p_active THEN 'ENABLE_LEGAL_HOLD' ELSE 'DISABLE_LEGAL_HOLD' END;

  -- Catat aksi ke admin_audit_logs (Immutable)
  INSERT INTO public.admin_audit_logs (
    admin_id,
    action_type,
    target_user_id,
    reason,
    metadata
  ) VALUES (
    v_admin_id,
    v_action,
    p_target_user_id,
    COALESCE(p_case_ref, 'Status Legal Hold diubah oleh administrator'),
    jsonb_build_object('legal_hold_active', p_active, 'case_ref', p_case_ref)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.admin_set_legal_hold(uuid, boolean, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_legal_hold(uuid, boolean, text, uuid) TO authenticated;


-- ----------------------------------------------------------------------------
-- 2. Guard Legal Hold pada execute_room_scheduled_wipe
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.execute_room_scheduled_wipe(p_room_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_mode VARCHAR(20);
  v_time TIME;
  v_target_at TIMESTAMPTZ;
BEGIN
  -- Verifikasi pemanggil atau sistem
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- LEGAL HOLD GUARD: Jangan hapus riwayat jika ada partisipan dalam status penahanan hukum
  IF EXISTS (
    SELECT 1 FROM public.room_participants rp
    JOIN public.profiles p ON p.id = rp.profile_id
    WHERE rp.room_id = p_room_id AND p.legal_hold_active = true
  ) THEN
    RETURN 0;
  END IF;

  -- Hapus semua pesan di room
  DELETE FROM public.messages
  WHERE room_id = p_room_id
    AND created_at <= now();
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  -- Ambil status mode saat ini
  SELECT scheduled_wipe_mode, scheduled_wipe_time, scheduled_wipe_target_at
  INTO v_mode, v_time, v_target_at
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_mode = 'one_shot' THEN
    UPDATE public.chat_rooms
    SET scheduled_wipe_mode = 'off',
        scheduled_wipe_time = NULL,
        scheduled_wipe_target_at = NULL
    WHERE id = p_room_id;
  ELSIF v_mode = 'daily' THEN
    -- Majukan target ke hari berikutnya pada jam yang sama
    UPDATE public.chat_rooms
    SET scheduled_wipe_target_at = (v_target_at + INTERVAL '1 day')
    WHERE id = p_room_id;
  END IF;

  RETURN v_deleted_count;
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. Guard Legal Hold pada execute_room_burn_on_exit
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.execute_room_burn_on_exit(
  p_room_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_burn_enabled BOOLEAN;
BEGIN
  -- Verifikasi pemanggil adalah anggota sah dari room tersebut
  IF NOT EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Akses ditolak: Anda bukan anggota ruangan ini';
  END IF;

  -- LEGAL HOLD GUARD: Jangan hapus jika ada partisipan dalam penahanan hukum
  IF EXISTS (
    SELECT 1 FROM public.room_participants rp
    JOIN public.profiles p ON p.id = rp.profile_id
    WHERE rp.room_id = p_room_id AND p.legal_hold_active = true
  ) THEN
    RETURN;
  END IF;

  -- Periksa apakah mode burn_on_exit aktif untuk ruangan ini
  SELECT burn_on_exit INTO v_burn_enabled
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_burn_enabled IS TRUE THEN
    -- Hapus seluruh riwayat pesan di ruangan ini
    DELETE FROM public.messages
    WHERE room_id = p_room_id;
  END IF;
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. Guard Legal Hold pada purge_expired_messages (Global & Disappearing)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_expired_messages()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count INTEGER := 0;
  r RECORD;
BEGIN
  -- A. Eksekusi pembersihan terjadwal untuk room yang sudah mencapai target
  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE scheduled_wipe_mode != 'off'
      AND scheduled_wipe_target_at IS NOT NULL
      AND scheduled_wipe_target_at <= now()
  LOOP
    PERFORM public.execute_room_scheduled_wipe(r.id);
  END LOOP;

  -- B. Hard delete pesan individual yang melewati auto_delete_at
  -- DENGAN PENGECUALIAN untuk pengirim atau room dengan partisipan yang aktif Legal Hold
  DELETE FROM public.messages m
  WHERE m.auto_delete_at IS NOT NULL
    AND m.auto_delete_at < now()
    AND NOT EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = m.sender_id AND p.legal_hold_active = true
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.room_participants rp
      JOIN public.profiles p ON p.id = rp.profile_id
      WHERE rp.room_id = m.room_id AND p.legal_hold_active = true
    );
  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RETURN deleted_count;
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. Guard Legal Hold pada delete_message_for_everyone
-- ----------------------------------------------------------------------------
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

    -- Only the sender can delete their own message
    IF msg_sender_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to delete this message';
    END IF;

    -- LEGAL HOLD GUARD: Blokir penghapusan jika pemanggil sedang dalam status Legal Hold
    IF EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND legal_hold_active = true
    ) THEN
      RAISE EXCEPTION 'LEGAL_HOLD_BLOCKED: Akun sedang dalam penahanan bukti hukum. Tindakan penghapusan pesan diblokir.';
    END IF;

    -- 2. Check room type (is it a guardian room or general?)
    SELECT (room_type = 'guardian') INTO room_is_guardian
    FROM public.chat_rooms
    WHERE id = msg_room_id;

    -- 3. Check if the message has been read by the OTHER participant
    SELECT MAX(last_read_at) INTO other_last_read
    FROM public.room_participants
    WHERE room_id = msg_room_id
      AND profile_id != auth.uid();

    -- 4. Determine deletion type
    IF room_is_guardian THEN
        UPDATE public.messages
        SET is_deleted = true,
            deleted_at = now(),
            updated_at = now()
        WHERE id = msg_uuid;
    ELSE
        IF other_last_read IS NULL OR msg_created_at > other_last_read THEN
            UPDATE public.messages
            SET is_silent_deleted = true,
                is_deleted = true,
                deleted_at = now(),
                updated_at = now()
            WHERE id = msg_uuid;
        ELSE
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

-- Grant izin eksekusi
REVOKE ALL ON FUNCTION public.execute_room_scheduled_wipe(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_room_scheduled_wipe(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.execute_room_burn_on_exit(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_room_burn_on_exit(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated;

REVOKE ALL ON FUNCTION public.delete_message_for_everyone(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_message_for_everyone(UUID) TO authenticated;

COMMIT;
