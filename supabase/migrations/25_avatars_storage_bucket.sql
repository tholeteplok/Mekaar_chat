-- Buat bucket avatars jika belum ada
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Hapus policy lama
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Avatar images are publicly accessible.' AND tablename = 'objects' AND schemaname = 'storage') THEN
    DROP POLICY "Avatar images are publicly accessible." ON storage.objects;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can upload their own avatar.' AND tablename = 'objects' AND schemaname = 'storage') THEN
    DROP POLICY "Users can upload their own avatar." ON storage.objects;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own avatar.' AND tablename = 'objects' AND schemaname = 'storage') THEN
    DROP POLICY "Users can update their own avatar." ON storage.objects;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own avatar.' AND tablename = 'objects' AND schemaname = 'storage') THEN
    DROP POLICY "Users can delete their own avatar." ON storage.objects;
  END IF;
END $$;

-- 1. Semua orang bisa melihat avatar (SELECT)
create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- 2. Pengguna hanya dapat mengunggah (INSERT) ke foldernya sendiri (berdasarkan UUID)
create policy "Users can upload their own avatar."
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- 3. Pengguna dapat mengupdate avatar mereka sendiri
create policy "Users can update their own avatar."
  on storage.objects for update
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- 4. Pengguna dapat menghapus avatar mereka sendiri
create policy "Users can delete their own avatar."
  on storage.objects for delete
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );
