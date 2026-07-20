-- Migration 22: Tambah kontak via QR code
-- profiles.invite_token = kredensial bearer untuk undangan guardian secara luring.
-- Pemilik QR menampilkan kode; pemindai menjadi OWNER dan mengirim undangan
-- (relasi lahir 'pending', pemilik QR tetap harus accept — consent dua pihak).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS invite_token TEXT;

UPDATE public.profiles
SET invite_token = replace(gen_random_uuid()::text, '-', '')
WHERE invite_token IS NULL;

ALTER TABLE public.profiles
  ALTER COLUMN invite_token SET DEFAULT replace(gen_random_uuid()::text, '-', '');

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_invite_token
  ON public.profiles (invite_token);

-- -----------------------------------------------------------------------------
-- Ganti token milik sendiri (mematikan QR lama yang mungkin tersebar).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rotate_invite_token()
RETURNS TEXT AS $$
DECLARE
  v_token TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_token := replace(gen_random_uuid()::text, '-', '');

  UPDATE public.profiles
  SET invite_token = v_token
  WHERE id = auth.uid();

  RETURN v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.rotate_invite_token() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rotate_invite_token() TO authenticated;

-- -----------------------------------------------------------------------------
-- Preview profil pemilik QR sebelum pemindai mengirim undangan.
-- Hanya kolom publik; kepemilikan token = bukti pertemuan luring.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.preview_invite_token(p_token TEXT)
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  avatar_url TEXT
) AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_token IS NULL OR length(trim(p_token)) < 16 THEN
    RAISE EXCEPTION 'Kode undangan tidak valid';
  END IF;

  RETURN QUERY
  SELECT p.id, p.username, p.full_name, p.avatar_url
  FROM public.profiles AS p
  WHERE p.invite_token = trim(p_token)
  LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.preview_invite_token(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.preview_invite_token(TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- Redeem: buat relasi pending (pemindai = owner, pemilik QR = guardian).
-- Validasi blokir dua arah + cooldown ditangani invite_guardian (migration 21).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.redeem_invite_token(
  p_token TEXT,
  p_permissions JSONB DEFAULT '{"gps": false, "mic": false, "video": false}'::jsonb
)
RETURNS UUID AS $$
DECLARE
  v_target_id UUID;
  v_relation_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_token IS NULL OR length(trim(p_token)) < 16 THEN
    RAISE EXCEPTION 'Kode undangan tidak valid';
  END IF;

  SELECT p.id
  INTO v_target_id
  FROM public.profiles AS p
  WHERE p.invite_token = trim(p_token)
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kode undangan tidak valid atau sudah diperbarui';
  END IF;

  IF v_target_id = auth.uid() THEN
    RAISE EXCEPTION 'Tidak bisa menambahkan diri sendiri';
  END IF;

  v_relation_id := public.invite_guardian(
    auth.uid(),
    v_target_id,
    COALESCE(p_permissions, '{"gps": false, "mic": false, "video": false}'::jsonb)
  );

  RETURN v_relation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.redeem_invite_token(TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_invite_token(TEXT, JSONB) TO authenticated;
