-- ============================================================================
-- MEKAAR 3.0 Migration 92: Orchestrate Chat Media Purge
--
-- Keterbatasan Paket Supabase Free Tier (Hobby Plan):
-- 1. Kuota Penyimpanan: Maksimal 1 GB total.
-- 2. Kuota Bandwidth Egress: Maksimal 2 GB per bulan.
--
-- Menghubungkan pemanggilan purge_expired_chat_media_storage() ke dalam
-- fungsi pembersih rutin purge_expired_messages() agar berkas fisik di
-- bucket 'chat-media' yang berumur lebih dari 30 hari otomatis dibersihkan
-- saat siklus pembersihan harian/rutin berjalan.
-- ============================================================================

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
  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE scheduled_wipe_mode != 'off'
      AND scheduled_wipe_target_at IS NOT NULL
      AND scheduled_wipe_target_at <= now()
  LOOP
    PERFORM public.execute_room_scheduled_wipe(r.id);
  END LOOP;

  -- 2. Bersihkan berkas fisik storage bucket 'chat-media' yang berumur > 30 hari
  -- Fail-safe didalam block exception agar kegagalan storage tidak membatalkan
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
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated, service_role;
