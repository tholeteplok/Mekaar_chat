-- ============================================================================
-- MEKAAR 3.0 Migration 106: Avatars Storage Bucket & RLS Policies Sync
-- Pencatatan resmi konfigurasi storage bucket 'avatars' dan RLS policies
-- agar tersinkronisasi antara database remote dan repositori lokal.
-- ============================================================================

BEGIN;

-- 1. Pastikan bucket 'avatars' ada dan berstatus publik
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 
  'avatars', 
  true, 
  5242880, -- Batas 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET 
  public = true,
  file_size_limit = 5242880;

-- 2. Bersihkan policy lama yang konflik pada storage.objects
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar select" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar insert" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar update" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated avatar delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow public avatar select" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read avatars" ON storage.objects;

-- 3. SELECT: Izinkan publik & authenticated melihat foto avatar
CREATE POLICY "Allow public avatar select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- 4. INSERT: Izinkan user upload ke folder miliknya sendiri (<uid>/...)
CREATE POLICY "Allow authenticated avatar insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR name LIKE (auth.uid()::text || '/%')
    )
  );

-- 5. UPDATE: Wajib ada agar 'upsert: true' saat menimpa foto lama tidak memicu 403
CREATE POLICY "Allow authenticated avatar update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR name LIKE (auth.uid()::text || '/%')
    )
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR name LIKE (auth.uid()::text || '/%')
    )
  );

-- 6. DELETE: Izinkan user menghapus avatar miliknya
CREATE POLICY "Allow authenticated avatar delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR name LIKE (auth.uid()::text || '/%')
    )
  );

COMMIT;
