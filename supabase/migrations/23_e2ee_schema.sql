-- Migration 23: Skema E2EE untuk chat 1:1 (teks, lokasi, dan media)
-- - profiles.e2ee_public_key : kunci publik X25519 (memang publik).
-- - profiles.e2ee_key_backup : private key terenkripsi (wrap key dari PIN),
--   hanya bisa dibaca pemiliknya (RLS profiles self-only) untuk restore perangkat.
-- - messages.is_encrypted    : penanda envelope ciphertext di kolom content.
-- Pesan lama tetap plaintext (is_encrypted = false).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS e2ee_public_key TEXT,
  ADD COLUMN IF NOT EXISTS e2ee_key_backup TEXT,
  ADD COLUMN IF NOT EXISTS e2ee_key_updated_at TIMESTAMPTZ;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN NOT NULL DEFAULT FALSE;

-- Expose kunci publik lewat view publik agar lawan chat bisa mengambilnya
-- tanpa membuka tabel profiles (kolom lain tetap sama, tambahan di akhir).
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  avatar_url,
  last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;
