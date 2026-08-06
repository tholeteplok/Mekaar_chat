-- ==============================================================================
-- Migration: 46_fix_avatars_storage_rls.sql
--
-- Fix StorageException 403 Unauthorized ("new row violates row-level security policy")
-- saat pengguna mengunggah atau mengganti foto profil di bucket 'avatars'.
-- ==============================================================================

BEGIN;

-- 1. Pastikan bucket 'avatars' ada dan berstatus publik
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Hapus kebijakan RLS lama untuk bucket 'avatars' agar tidak terjadi konflik
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar select" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar insert" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar update" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar delete" ON storage.objects;

-- 3. SELECT: Mengizinkan siapapun (publik/anon & authenticated) melihat objek di bucket 'avatars'
CREATE POLICY "Allow public avatar select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- 4. INSERT: Mengizinkan pengguna authenticated mengunggah avatar ke folder milik sendiri (UUID user)
CREATE POLICY "Allow authenticated avatar insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR owner = auth.uid()
    )
  );

-- 5. UPDATE: Mengizinkan pengguna authenticated memperbarui/upsert avatar milik sendiri
CREATE POLICY "Allow authenticated avatar update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR owner = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR owner = auth.uid()
    )
  );

-- 6. DELETE: Mengizinkan pengguna authenticated menghapus avatar milik sendiri
CREATE POLICY "Allow authenticated avatar delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR owner = auth.uid()
    )
  );

COMMIT;
