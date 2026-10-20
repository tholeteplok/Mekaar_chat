-- ============================================================================
-- MEKAAR 3.0 Migration 91: File Attachment Message Type & Storage Auto-Purge
--
-- Keterbatasan Paket Supabase Free Tier (Hobby Plan):
-- 1. Kuota Penyimpanan: Maksimal 1 GB total.
-- 2. Kuota Bandwidth Egress: Maksimal 2 GB per bulan.
-- Berkas fisik pada bucket 'chat-media' otomatis dibersihkan setelah 30 hari
-- untuk mendaur ulang kuota penyimpanan gratis agar tidak over-quota.
-- Berkas yang telah diunduh oleh pengguna tetap tersimpan aman di perangkat lokal.
-- ============================================================================

-- 1. Perbarui CHECK constraint pada tabel messages untuk mendukung tipe 'file'
DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    FOR constraint_record IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.messages'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) LIKE '%msg_type%'
    LOOP
        EXECUTE 'ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_record.conname);
    END LOOP;
END $$;

ALTER TABLE public.messages
    ADD CONSTRAINT messages_msg_type_check
    CHECK (msg_type IN ('text', 'image', 'voice', 'video', 'system', 'location', 'file'));

-- 2. Fungsi pembersihan berkas storage yang berusia lebih dari 30 hari
-- Mendaur ulang kapasitas storage Supabase Free Tier (1 GB) secara berkala
CREATE OR REPLACE FUNCTION public.purge_expired_chat_media_storage()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, pg_temp
AS $$
DECLARE
    deleted_count integer := 0;
BEGIN
    -- Menghapus objek berkas pada bucket 'chat-media' yang dibuat lebih dari 30 hari lalu
    -- Keterbatasan Paket Supabase: kuota 1 GB storage free tier
    DELETE FROM storage.objects
    WHERE bucket_id = 'chat-media'
      AND created_at < (now() - INTERVAL '30 days');

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
EXCEPTION WHEN OTHERS THEN
    -- Fail-safe jika tabel storage.objects dilindungi atau sedang locked
    RAISE WARNING 'purge_expired_chat_media_storage failed: %', SQLERRM;
    RETURN 0;
END;
$$;

-- Berikan hak eksekusi ke role service_role
GRANT EXECUTE ON FUNCTION public.purge_expired_chat_media_storage() TO service_role;
