-- ==============================================================================
-- Migration: 76_fix_device_deduplication.sql
--
-- Memperbaiki deduplikasi perangkat pada tabel user_devices:
-- 1. register_device() otomatis menghapus baris lama milik user yang sama
--    yang memiliki fcm_token sama persis atau device_label yang sama dengan device_id lama.
-- 2. cleanup_my_duplicate_devices() untuk membersihkan baris duplikat yang sudah ada.
-- ==============================================================================

BEGIN;

-- ── 1. Update RPC register_device dengan deduplikasi otomatis ──
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
  -- 1. Deduplikasi: Hapus baris lama milik user ini jika memiliki fcm_token yang sama persis
  --    tapi dengan device_id berbeda (kasus update aplikasi / instalasi ulang / keystore reset).
  IF p_fcm_token IS NOT NULL AND p_fcm_token <> '' THEN
    DELETE FROM public.user_devices
    WHERE profile_id = auth.uid()
      AND fcm_token = p_fcm_token
      AND device_id <> p_device_id;
  END IF;

  -- 2. Deduplikasi tambahan: Jika ada baris dengan device_label + platform sama yang dibuat sebelumnya
  --    tanpa fcm_token aktif, bersihkan agar tidak ada entri ghost.
  IF p_device_label IS NOT NULL AND p_device_label <> '' THEN
    DELETE FROM public.user_devices
    WHERE profile_id = auth.uid()
      AND device_label = p_device_label
      AND platform = p_platform
      AND device_id <> p_device_id
      AND (fcm_token IS NULL OR fcm_token = p_fcm_token);
  END IF;

  -- 3. Insert / Update device saat ini
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

  -- Backward compat: update profiles.fcm_token (fallback transisi)
  IF p_fcm_token IS NOT NULL AND p_fcm_token <> '' THEN
    UPDATE public.profiles
    SET fcm_token = p_fcm_token, fcm_token_updated_at = now()
    WHERE id = auth.uid();
  END IF;

  RETURN v_id;
END;
$$;

-- ── 2. RPC untuk membersihkan semua baris duplikat yang sudah ada ──
CREATE OR REPLACE FUNCTION public.cleanup_my_duplicate_devices()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
BEGIN
  -- Hapus entri yang memiliki device_label & platform sama, sisakan hanya baris dengan last_seen_at terbaru
  WITH ranked_devices AS (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY profile_id, device_label, platform
             ORDER BY last_seen_at DESC, created_at DESC
           ) as rank_num
    FROM public.user_devices
    WHERE profile_id = auth.uid()
  ),
  to_delete AS (
    SELECT id FROM ranked_devices WHERE rank_num > 1
  )
  DELETE FROM public.user_devices
  WHERE id IN (SELECT id FROM to_delete);

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$;

-- ── 3. Grants ──
GRANT EXECUTE ON FUNCTION public.register_device(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_my_duplicate_devices() TO authenticated;

COMMIT;
