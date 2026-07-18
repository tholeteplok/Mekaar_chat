-- Migration 18: Two-Factor Authentication (TOTP) + login device tracking
-- Additive only - safe to run on existing databases.

-- ─────────────────────────────────────────
-- 1. 2FA columns on profiles
-- ─────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS two_fa_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS two_fa_secret TEXT,
  ADD COLUMN IF NOT EXISTS last_login_device TEXT,
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

-- ─────────────────────────────────────────
-- 2. RPC: enable_2fa(secret) — simpan secret & aktifkan
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enable_2fa(secret TEXT)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  UPDATE public.profiles
  SET two_fa_enabled = true,
      two_fa_secret = secret,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.enable_2fa(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enable_2fa(TEXT) TO authenticated;

-- ─────────────────────────────────────────
-- 3. RPC: disable_2fa() — matikan & hapus secret
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.disable_2fa()
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  UPDATE public.profiles
  SET two_fa_enabled = false,
      two_fa_secret = NULL,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.disable_2fa() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.disable_2fa() TO authenticated;

-- ─────────────────────────────────────────
-- 4. RPC: record_login_device(device_name) — catat device & waktu login
--    Mengembalikan TRUE jika device BERBEDA dari login sebelumnya.
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_login_device(device_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  prev_device TEXT;
  is_new BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN RETURN FALSE; END IF;

  SELECT last_login_device INTO prev_device
  FROM public.profiles WHERE id = auth.uid();

  is_new := (prev_device IS NULL) OR (prev_device <> device_name);

  UPDATE public.profiles
  SET last_login_device = device_name,
      last_login_at = now(),
      updated_at = now()
  WHERE id = auth.uid();

  RETURN is_new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.record_login_device(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_login_device(TEXT) TO authenticated;
