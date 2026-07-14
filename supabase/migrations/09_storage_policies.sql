-- Migration 09: Storage bucket and security policies for chat-media
-- Creates the 'chat-media' bucket and configures RLS policies to allow authenticated users to upload and view media.

-- 1. Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-media', 'chat-media', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to upload (INSERT) files to 'chat-media' bucket
CREATE POLICY "Allow authenticated uploads to chat-media" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'chat-media'
  AND (auth.uid() IS NOT NULL)
);

-- 3. Allow authenticated users to view (SELECT) files from 'chat-media' bucket
CREATE POLICY "Allow authenticated access to chat-media" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'chat-media'
);

-- 4. Allow users to delete their own uploaded files from 'chat-media' bucket
CREATE POLICY "Allow owner to delete their chat-media" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'chat-media'
  AND owner = auth.uid()
);
