-- Migration 25: display_name untuk profil pengguna
-- - Tambah kolom display_name pada profiles
-- - Update public_profiles view
-- - Update search_public_profiles RPC

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Drop dulu karena CREATE OR REPLACE VIEW tidak bisa mengubah urutan/tipe kolom
DROP VIEW IF EXISTS public.public_profiles;

CREATE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;

-- Update search_public_profiles RPC
DROP FUNCTION IF EXISTS public.search_public_profiles(TEXT);

CREATE OR REPLACE FUNCTION public.search_public_profiles(search_query TEXT)
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  display_name TEXT,
  avatar_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.username,
    p.full_name,
    p.display_name,
    p.avatar_url
  FROM public.profiles AS p
  WHERE
    auth.uid() IS NOT NULL
    AND search_query IS NOT NULL
    AND length(trim(search_query)) >= 2
    AND p.username = trim(search_query)
  ORDER BY p.username ASC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.search_public_profiles(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(TEXT) TO authenticated;
