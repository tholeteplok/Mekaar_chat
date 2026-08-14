-- ==============================================================================
-- MEKAAR 3.0 Migration 61: Fix Avatars Public Storage RLS
--
-- Masalah:
--   Pada migration 55 (DB-5), policy SELECT storage.objects untuk bucket 'avatars'
--   dibatasi "TO authenticated".
--   Flutter Image.network memuat gambar via HTTP GET tanpa token auth Supabase (anon).
--   Akibatnya, setiap cold restart aplikasi, gambar avatar gagal dimuat (403 Forbidden)
--   dan widget avatar jatuh kembali ke fallback huruf inisial.
--
-- Solusi:
--   1. Pastikan bucket 'avatars' berstatus public = true.
--   2. Izinkan SELECT untuk publik/anon dan authenticated pada bucket 'avatars'.
--   3. Tetap pertahankan keamanan INSERT/UPDATE/DELETE agar hanya user pemilik
--      (auth.uid() = folder UUID) yang dapat mengubah/mengunggah file miliknya.
-- ==============================================================================

BEGIN;

-- 1. Pastikan bucket 'avatars' ada dan berstatus publik
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Bersihkan kebijakan SELECT lama yang memblokir akses publik
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar select" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow public avatar select" ON storage.objects;

-- 3. SELECT: Izinkan siapapun (anon & authenticated) melihat/mengunduh objek avatar
CREATE POLICY "Allow public avatar select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- 4. INSERT: Hanya authenticated user yang bisa upload ke foldernya sendiri (UUID)
DROP POLICY IF EXISTS "Users can upload their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar insert" ON storage.objects;

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

-- 5. UPDATE: Hanya authenticated user yang bisa update avatar di foldernya sendiri
DROP POLICY IF EXISTS "Users can update their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar update" ON storage.objects;

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

-- 6. DELETE: Hanya authenticated user yang bisa hapus avatar di foldernya sendiri
DROP POLICY IF EXISTS "Users can delete their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar delete" ON storage.objects;

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
