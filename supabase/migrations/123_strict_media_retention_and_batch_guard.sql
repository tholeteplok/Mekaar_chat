-- ============================================================================
-- MEKAAR 3.0 Migration 123: Strict Media Retention, Orphan Cleanup & Batch Guard
-- ============================================================================
-- 1. Menetapkan batas keras ukuran objek bucket 'chat-media' (15 MB = 15728640 bytes).
-- 2. Menambahkan rate-limit upload per pengguna (maks 20 objek / 10 menit) di RLS INSERT.
-- 3. Memperketat TTL auto-purge storage bucket 'chat-media' menjadi 7 hari +
--    pembersihan langsung file orphan (pesan yang sudah dihapus/expired > 1 jam),
--    dengan tetap menghormati status Legal Hold (profiles.legal_hold_active).
-- 4. Menjalankan pembersihan storage SETELAH hard-delete pesan expired di
--    purge_expired_messages() agar media dari pesan expired ikut terhapus segera.
-- ============================================================================

BEGIN;

-- 1. Batas keras ukuran berkas pada bucket chat-media (15 MB)
UPDATE storage.buckets
SET file_size_limit = 15728640
WHERE id = 'chat-media';

-- 2. Fungsi rate-limit upload media per pengguna (maks 20 berkas per 10 menit)
CREATE OR REPLACE FUNCTION public.can_upload_chat_media()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, storage, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_recent_count integer := 0;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  SELECT COUNT(*)
  INTO v_recent_count
  FROM storage.objects
  WHERE bucket_id = 'chat-media'
    AND owner = v_uid
    AND created_at >= (now() - INTERVAL '10 minutes');

  RETURN v_recent_count < 20;
END;
$$;

REVOKE ALL ON FUNCTION public.can_upload_chat_media() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_upload_chat_media() TO authenticated;

-- 3. Perbarui RLS INSERT pada storage.objects agar memakai guard rate-limit
DROP POLICY IF EXISTS "Allow authenticated uploads to chat-media" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to chat-media" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'chat-media'
  AND public.can_upload_chat_media()
);

-- 4. Perketat auto-purge storage: TTL default 7 hari + hapus file orphan + guard Legal Hold
CREATE OR REPLACE FUNCTION public.purge_expired_chat_media_storage(
  p_retention_days integer DEFAULT 7
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, pg_temp
AS $$
DECLARE
  deleted_count integer := 0;
  v_days integer := GREATEST(1, COALESCE(p_retention_days, 7));
BEGIN
  DELETE FROM storage.objects o
  WHERE o.bucket_id = 'chat-media'
    AND (
      -- A. Objek melampaui TTL retensi (7 hari) dan tidak terkait pesan Legal Hold
      (
        o.created_at < (now() - make_interval(days => v_days))
        AND NOT EXISTS (
          SELECT 1
          FROM public.messages m
          WHERE m.media_url IS NOT NULL
            AND strpos(m.media_url, '/chat-media/' || o.name) > 0
            AND (
              EXISTS (
                SELECT 1 FROM public.profiles p
                WHERE p.id = m.sender_id AND p.legal_hold_active = true
              )
              OR EXISTS (
                SELECT 1
                FROM public.room_participants rp
                JOIN public.profiles p ON p.id = rp.profile_id
                WHERE rp.room_id = m.room_id AND p.legal_hold_active = true
              )
            )
        )
      )
      OR
      -- B. Pembersihan file orphan (pesan sudah dihapus/expired, minimal umur 1 jam
      --    agar upload in-flight yang belum selesai insert pesan tidak ikut terhapus)
      (
        o.created_at < (now() - INTERVAL '1 hour')
        AND NOT EXISTS (
          SELECT 1
          FROM public.messages m
          WHERE m.media_url IS NOT NULL
            AND strpos(m.media_url, '/chat-media/' || o.name) > 0
        )
      )
    );

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
EXCEPTION WHEN OTHERS THEN
  -- Fail-safe jika tabel storage.objects dilindungi atau sedang locked
  RAISE WARNING 'purge_expired_chat_media_storage failed: %', SQLERRM;
  RETURN 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.purge_expired_chat_media_storage(integer) TO service_role;

-- 5. Perbarui purge_expired_messages (melanjutkan Migrasi 114):
--    Jalankan pembersihan storage SETELAH pesan expired/wiped dihapus agar file
--    orphan langsung dibersihkan dalam siklus yang sama.
CREATE OR REPLACE FUNCTION public.purge_expired_messages()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, pg_temp
AS $$
DECLARE
  deleted_msg_count INTEGER := 0;
  deleted_calls_count INTEGER := 0;
  deleted_media_count INTEGER := 0;
  r RECORD;
BEGIN
  -- 1. Eksekusi pembersihan terjadwal untuk room yang sudah mencapai target wipe
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

  -- 2. Hard delete pesan individual yang melewati auto_delete_at (dengan Legal Hold Guard)
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

  -- 3. Hard delete riwayat panggilan (calls) yang umurnya melewati disappearing_hours
  DELETE FROM public.calls c
  USING public.chat_rooms cr
  WHERE c.room_id = cr.id
    AND cr.disappearing_hours > 0
    AND c.created_at < (now() - (cr.disappearing_hours || ' hours')::INTERVAL)
    AND NOT EXISTS (
      SELECT 1 FROM public.room_participants rp
      JOIN public.profiles p ON p.id = rp.profile_id
      WHERE rp.room_id = c.room_id AND p.legal_hold_active = true
    );
  GET DIAGNOSTICS deleted_calls_count = ROW_COUNT;

  -- 4. Bersihkan berkas fisik storage bucket 'chat-media' (TTL 7 hari + orphan cleanup)
  BEGIN
    SELECT public.purge_expired_chat_media_storage(7) INTO deleted_media_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'purge_expired_chat_media_storage execution failed in purge_expired_messages: %', SQLERRM;
  END;

  RETURN (deleted_msg_count + deleted_calls_count);
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated, service_role;

COMMIT;
