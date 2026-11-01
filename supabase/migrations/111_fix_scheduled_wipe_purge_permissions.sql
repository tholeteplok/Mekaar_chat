-- ============================================================================
-- MEKAAR 3.0 Migration 111: Fix Scheduled Wipe Purge Permissions & Exception Isolation
--
-- Masalah pada migrasi 92 & 65:
-- Saat dipanggil oleh authenticated user (misal client HP memicu pembersihan rutin),
-- loop chat_rooms mencoba mengeksekusi execute_room_scheduled_wipe() pada semua
-- room yang kedaluwarsa tanpa memeriksa apakah auth.uid() adalah anggota sah.
-- Ini menyebabkan RAISE EXCEPTION 'Akses ditolak' yang membatalkan (ROLLBACK)
-- seluruh transaksi termasuk penghapusan pesan di room milik pengguna itu sendiri.
--
-- Solusi:
-- 1. Filter chat_rooms agar authenticated user hanya mengeksekusi wipe pada
--    ruangan di mana ia menjadi anggota sah (auth.uid() IS NULL tetap memproses semua).
-- 2. Bungkus eksekusi per room dalam sub-blok EXCEPTION agar kegagalan individual
--    tidak menggugurkan pembersihan pesan expired lainnya.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.purge_expired_messages()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, pg_temp
AS $$
DECLARE
  deleted_msg_count INTEGER := 0;
  deleted_media_count INTEGER := 0;
  r RECORD;
BEGIN
  -- 1. Eksekusi pembersihan terjadwal untuk room yang sudah mencapai target wipe
  -- Filter agar hanya memproses room yang sah bagi pemanggil (atau semua jika service_role/cron)
  FOR r IN
    SELECT cr.id FROM public.chat_rooms cr
    WHERE cr.scheduled_wipe_mode != 'off'
      AND cr.scheduled_wipe_target_at IS NOT NULL
      AND cr.scheduled_wipe_target_at <= now()
      AND (
        auth.uid() IS NULL
        OR EXISTS (
          SELECT 1 FROM public.room_participants rp
          WHERE rp.room_id = cr.id
            AND rp.profile_id = auth.uid()
            AND rp.deleted_at IS NULL
        )
      )
  LOOP
    BEGIN
      PERFORM public.execute_room_scheduled_wipe(r.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'execute_room_scheduled_wipe gagal untuk room %: %', r.id, SQLERRM;
    END;
  END LOOP;

  -- 2. Bersihkan berkas fisik storage bucket 'chat-media' yang berumur > 30 hari
  -- Fail-safe di dalam block exception agar kegagalan storage tidak membatalkan
  -- penghapusan pesan teks expired lainnya.
  BEGIN
    SELECT public.purge_expired_chat_media_storage() INTO deleted_media_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'purge_expired_chat_media_storage execution failed in purge_expired_messages: %', SQLERRM;
  END;

  -- 3. Hard delete pesan individual yang melewati auto_delete_at
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
  GET DIAGNOSTICS deleted_msg_count = ROW_COUNT;

  RETURN deleted_msg_count;
END;
$$;

-- Berikan izin eksekusi ke authenticated dan service_role
REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated, service_role;

COMMIT;
