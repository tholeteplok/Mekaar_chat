-- Migration 108: Memperbaiki izin UPDATE dan keamanan fungsi proteksi privasi obrolan
-- (Memulihkan kemampuan toggle Proteksi Layar & Larang Teruskan Pesan pada room_participants)

-- 1. Berikan column-level UPDATE grant pada kolom proteksi obrolan ke authenticated
GRANT UPDATE (
  screenshot_protection_enabled,
  screenshot_protection_updated_at,
  forwarding_protection_enabled,
  forwarding_protection_updated_at
) ON public.room_participants TO authenticated;

-- 2. Tingkatkan set_room_screenshot_protection menjadi SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.set_room_screenshot_protection(
  p_room_id UUID,
  p_enabled BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  updated BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  UPDATE public.room_participants
  SET screenshot_protection_enabled = p_enabled
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
  RETURNING screenshot_protection_enabled INTO updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room participant not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN updated;
END;
$$;

-- 3. Tingkatkan get_room_screenshot_protection menjadi SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.get_room_screenshot_protection(
  p_room_id UUID
)
RETURNS TABLE (
  effective BOOLEAN,
  caller_enabled BOOLEAN,
  protector_count BIGINT,
  participant_count BIGINT,
  last_change TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Room participant not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(bool_or(rp.screenshot_protection_enabled), TRUE),
    COALESCE(
      bool_or(rp.screenshot_protection_enabled)
        FILTER (WHERE rp.profile_id = auth.uid()),
      TRUE
    ),
    COUNT(*) FILTER (WHERE rp.screenshot_protection_enabled),
    COUNT(*)::BIGINT,
    MAX(rp.screenshot_protection_updated_at)
  FROM public.room_participants rp
  WHERE rp.room_id = p_room_id;
END;
$$;

-- 4. Tingkatkan set_room_forwarding_protection menjadi SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.set_room_forwarding_protection(
  p_room_id UUID,
  p_enabled BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  updated BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  UPDATE public.room_participants
  SET forwarding_protection_enabled = p_enabled
  WHERE room_id = p_room_id
    AND profile_id = auth.uid()
  RETURNING forwarding_protection_enabled INTO updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room participant not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN updated;
END;
$$;

-- 5. Tingkatkan get_room_forwarding_protection menjadi SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.get_room_forwarding_protection(
  p_room_id UUID
)
RETURNS TABLE (
  effective BOOLEAN,
  caller_enabled BOOLEAN,
  protector_count BIGINT,
  participant_count BIGINT,
  last_change TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.room_participants
    WHERE room_id = p_room_id
      AND profile_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Room participant not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(bool_or(rp.forwarding_protection_enabled), TRUE),
    COALESCE(
      bool_or(rp.forwarding_protection_enabled)
        FILTER (WHERE rp.profile_id = auth.uid()),
      TRUE
    ),
    COUNT(*) FILTER (WHERE rp.forwarding_protection_enabled),
    COUNT(*)::BIGINT,
    MAX(rp.forwarding_protection_updated_at)
  FROM public.room_participants rp
  WHERE rp.room_id = p_room_id;
END;
$$;

-- 6. Hak eksekusi eksplisit untuk authenticated
REVOKE ALL ON FUNCTION public.set_room_screenshot_protection(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_room_screenshot_protection(UUID, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.get_room_screenshot_protection(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_room_screenshot_protection(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.set_room_forwarding_protection(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_room_forwarding_protection(UUID, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.get_room_forwarding_protection(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_room_forwarding_protection(UUID) TO authenticated;
