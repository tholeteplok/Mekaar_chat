-- Migration 21: Contact privacy hardening
-- 1) Pembuatan relasi guardian dikunci ke RPC invite_guardian (consent server-side).
-- 2) RLS guardians dipecah per peran: guardian tidak bisa menaikkan izin sendiri.
-- 3) Accept undangan lewat RPC accept_guardian_invite (guardian-side, status saja).
-- 4) CHECK constraint untuk status relasi.
-- 5) Rate limit resolve_login_email (oracle email/username publik).
-- 6) search_public_profiles hanya cocok username (tutup enumerasi email).

-- -----------------------------------------------------------------------------
-- 1. RPC invite_guardian: satu-satunya jalur membuat relasi guardian.
--    Caller harus salah satu pihak; validasi blokir dua arah + cooldown break;
--    status/expires_at dipaksa di server (bukan dari client).
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.invite_guardian(
  p_owner UUID,
  p_guardian UUID,
  p_permissions JSONB DEFAULT '{"gps": false, "mic": false, "video": false}'::jsonb
)
RETURNS UUID AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_id UUID;
  v_blocked_until TIMESTAMPTZ;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_owner IS NULL OR p_guardian IS NULL THEN
    RAISE EXCEPTION 'Pihak relasi tidak lengkap';
  END IF;

  IF p_owner = p_guardian THEN
    RAISE EXCEPTION 'Tidak bisa membuat relasi dengan diri sendiri';
  END IF;

  IF v_caller <> p_owner AND v_caller <> p_guardian THEN
    RAISE EXCEPTION 'Anda bukan pihak dalam relasi ini';
  END IF;

  -- Blokir dua arah: jika salah satu memblokir, relasi tidak boleh dibuat.
  IF EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_id = p_owner AND blocked_id = p_guardian)
       OR (blocker_id = p_guardian AND blocked_id = p_owner)
  ) THEN
    RAISE EXCEPTION 'Relasi tidak dapat dibuat';
  END IF;

  -- Cooldown 24 jam setelah panic unlink (menghidupkan blocked_until).
  SELECT g.blocked_until
  INTO v_blocked_until
  FROM public.guardians AS g
  WHERE g.owner_id = p_owner
    AND g.guardian_id = p_guardian
    AND g.blocked_until IS NOT NULL
  LIMIT 1;

  IF v_blocked_until IS NOT NULL AND v_blocked_until > now() THEN
    RAISE EXCEPTION 'Undangan ke pengguna ini diblokir sementara';
  END IF;

  INSERT INTO public.guardians (
    owner_id, guardian_id, permissions, status, expires_at, blocked_until, broken_by_owner
  ) VALUES (
    p_owner,
    p_guardian,
    COALESCE(p_permissions, '{"gps": false, "mic": false, "video": false}'::jsonb),
    'pending',
    now() + interval '30 days',
    NULL,
    FALSE
  )
  ON CONFLICT (owner_id, guardian_id) DO UPDATE
    SET permissions = EXCLUDED.permissions,
        status = 'pending',
        expires_at = now() + interval '30 days',
        blocked_until = NULL,
        broken_by_owner = FALSE
  WHERE public.guardians.status IN ('expired', 'broken')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Relasi guardian sudah ada';
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.invite_guardian(UUID, UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_guardian(UUID, UUID, JSONB) TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. RPC accept_guardian_invite: guardian hanya bisa menerima undangan
--    (status pending -> active, expiry server-side). Kolom lain tidak tersentuh.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.accept_guardian_invite(p_relation_id UUID)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.guardians
  SET status = 'active',
      expires_at = now() + interval '30 days'
  WHERE id = p_relation_id
    AND guardian_id = auth.uid()
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Undangan tidak ditemukan atau sudah diproses';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.accept_guardian_invite(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_guardian_invite(UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. RLS guardians: pecah policy ALL menjadi per-perintah.
--    INSERT dicabut dari authenticated (wajib lewat invite_guardian);
--    UPDATE hanya owner (guardian accept lewat RPC) sehingga eskalasi izin
--    mandiri tidak mungkin; DELETE tetap dua pihak (tolak undangan/hapus).
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can manage own guardian relations" ON public.guardians;

CREATE POLICY "Parties can view guardian relations" ON public.guardians
  FOR SELECT USING (auth.uid() = owner_id OR auth.uid() = guardian_id);

CREATE POLICY "Owners can update guardian relations" ON public.guardians
  FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Parties can delete guardian relations" ON public.guardians
  FOR DELETE USING (auth.uid() = owner_id OR auth.uid() = guardian_id);

REVOKE INSERT ON public.guardians FROM authenticated;

-- -----------------------------------------------------------------------------
-- 4. CHECK constraint status relasi (nilai 'broken' sebelumnya hanya ada di app).
-- -----------------------------------------------------------------------------

ALTER TABLE public.guardians DROP CONSTRAINT IF EXISTS guardians_status_check;
ALTER TABLE public.guardians
  ADD CONSTRAINT guardians_status_check
  CHECK (status IN ('pending', 'active', 'expired', 'broken'));

-- -----------------------------------------------------------------------------
-- 5. Rate limit resolve_login_email: tetap anon (dibutuhkan pre-login),
--    tapi maks 5 percobaan/menit per pemanggil (IP dari header / uid).
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.auth_resolve_attempts (
  caller TEXT NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_resolve_attempts_caller
  ON public.auth_resolve_attempts (caller, attempted_at DESC);

ALTER TABLE public.auth_resolve_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auth_resolve_attempts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.resolve_login_email(input_query TEXT)
RETURNS TEXT AS $$
DECLARE
  result_email TEXT;
  v_caller TEXT;
  v_recent INT;
BEGIN
  v_caller := COALESCE(
    auth.uid()::text,
    nullif(
      split_part(
        COALESCE(current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', ''),
        ',',
        1
      ),
      ''
    ),
    'unknown'
  );

  -- Bersihkan jejak lama sekalian jalan (volume rendah).
  DELETE FROM public.auth_resolve_attempts
  WHERE attempted_at < now() - interval '1 hour';

  SELECT count(*)
  INTO v_recent
  FROM public.auth_resolve_attempts
  WHERE caller = v_caller
    AND attempted_at > now() - interval '1 minute';

  IF v_recent >= 5 THEN
    RAISE EXCEPTION 'Terlalu banyak percobaan, coba lagi nanti';
  END IF;

  INSERT INTO public.auth_resolve_attempts (caller) VALUES (v_caller);

  -- Jika input tampak seperti email, kembalikan langsung.
  IF trim(input_query) LIKE '%@%' THEN
    RETURN trim(input_query);
  END IF;

  SELECT email INTO result_email
  FROM public.profiles
  WHERE lower(username) = lower(trim(input_query))
  LIMIT 1;

  RETURN result_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.resolve_login_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- 6. search_public_profiles: hanya username persis (bukan email).
--    Jalur tambah kontak utama sekarang: username atau QR (migration 22).
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_public_profiles(search_query TEXT)
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  avatar_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.username,
    p.full_name,
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
