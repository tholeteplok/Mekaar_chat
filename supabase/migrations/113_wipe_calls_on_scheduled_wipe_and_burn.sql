-- ============================================================================
-- Migrasi 113: Hapus Riwayat Panggilan (public.calls) saat Scheduled Wipe & Burn on Exit
-- ============================================================================
-- Mengatasi regresi di mana CallHistoryBubble tetap tertinggal setelah
-- pembersihan obrolan terjadwal atau saat fitur Burn on Exit terpicu.
-- ============================================================================

-- 1. Perbarui execute_room_scheduled_wipe agar menghapus public.calls
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

  -- Hapus semua riwayat panggilan di room
  DELETE FROM public.calls
  WHERE room_id = p_room_id
    AND created_at <= now();

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

-- 2. Perbarui execute_room_burn_on_exit agar menghapus public.calls
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

    -- Hapus seluruh riwayat panggilan di ruangan ini
    DELETE FROM public.calls
    WHERE room_id = p_room_id;
  END IF;
END;
$$;

-- Permissions hardening
REVOKE ALL ON FUNCTION public.execute_room_scheduled_wipe(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_room_scheduled_wipe(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.execute_room_burn_on_exit(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_room_burn_on_exit(uuid) TO authenticated, service_role;
