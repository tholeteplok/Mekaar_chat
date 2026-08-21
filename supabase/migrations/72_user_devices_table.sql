-- ==============================================================================
-- Migration: 72_user_devices_table.sql
--
-- Infrastruktur multi-device: setiap instalasi aplikasi mendapat baris unik
-- di tabel user_devices, menggantikan kolom tunggal profiles.fcm_token
-- sebagai sumber kebenaran token push notification.
--
-- profiles.fcm_token dipertahankan sementara sebagai fallback backward-compat
-- selama masa transisi (hingga semua device terupdate ke versi baru).
-- ==============================================================================

BEGIN;

-- ── 1. Tabel user_devices ──
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  fcm_token TEXT,
  device_label TEXT,
  platform TEXT NOT NULL DEFAULT 'unknown',
  app_version TEXT,
  last_seen_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(profile_id, device_id)
);

-- Index untuk lookup cepat
CREATE INDEX IF NOT EXISTS idx_user_devices_profile
  ON public.user_devices(profile_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm
  ON public.user_devices(fcm_token)
  WHERE fcm_token IS NOT NULL;

-- ── 2. RLS ──
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own devices"
  ON public.user_devices FOR SELECT TO authenticated
  USING (profile_id = auth.uid());

CREATE POLICY "Users can insert own devices"
  ON public.user_devices FOR INSERT TO authenticated
  WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can update own devices"
  ON public.user_devices FOR UPDATE TO authenticated
  USING (profile_id = auth.uid());

CREATE POLICY "Users can delete own devices"
  ON public.user_devices FOR DELETE TO authenticated
  USING (profile_id = auth.uid());

-- Service role bisa baca semua (untuk Edge Function push)
CREATE POLICY "Service role can read all devices"
  ON public.user_devices FOR SELECT TO service_role
  USING (true);

-- ── 3. RPC: Register / update device saat app start ──
CREATE OR REPLACE FUNCTION public.register_device(
  p_device_id TEXT,
  p_fcm_token TEXT DEFAULT NULL,
  p_device_label TEXT DEFAULT NULL,
  p_platform TEXT DEFAULT 'unknown',
  p_app_version TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.user_devices (
    profile_id, device_id, fcm_token, device_label, platform, app_version, last_seen_at
  )
  VALUES (
    auth.uid(), p_device_id, p_fcm_token, p_device_label, p_platform, p_app_version, now()
  )
  ON CONFLICT (profile_id, device_id) DO UPDATE SET
    fcm_token = COALESCE(EXCLUDED.fcm_token, user_devices.fcm_token),
    device_label = COALESCE(EXCLUDED.device_label, user_devices.device_label),
    platform = EXCLUDED.platform,
    app_version = COALESCE(EXCLUDED.app_version, user_devices.app_version),
    last_seen_at = now()
  RETURNING id INTO v_id;

  -- Backward compat: juga update profiles.fcm_token (fallback selama transisi)
  IF p_fcm_token IS NOT NULL THEN
    UPDATE public.profiles
    SET fcm_token = p_fcm_token, fcm_token_updated_at = now()
    WHERE id = auth.uid();
  END IF;

  RETURN v_id;
END;
$$;

-- ── 4. RPC: List semua device milik user ──
CREATE OR REPLACE FUNCTION public.list_my_devices()
RETURNS SETOF public.user_devices
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM public.user_devices
  WHERE profile_id = auth.uid()
  ORDER BY last_seen_at DESC;
$$;

-- ── 5. RPC: Revoke (hapus) device tertentu ──
CREATE OR REPLACE FUNCTION public.revoke_device(p_device_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.user_devices
  WHERE profile_id = auth.uid() AND device_id = p_device_id;
END;
$$;

-- ── 6. RPC: Clear FCM token hanya untuk device ini (logout per-device) ──
CREATE OR REPLACE FUNCTION public.clear_device_fcm_token(p_device_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_devices
  SET fcm_token = NULL
  WHERE profile_id = auth.uid() AND device_id = p_device_id;
END;
$$;

-- ── 7. Grants ──
GRANT EXECUTE ON FUNCTION public.register_device(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_devices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_device(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_device_fcm_token(TEXT) TO authenticated;

COMMIT;
