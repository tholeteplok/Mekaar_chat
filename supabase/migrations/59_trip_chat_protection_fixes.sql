-- ============================================================================
-- MEKAAR 3.0 Migration 59: Trip Permission & Chat Protection Fixes
-- ============================================================================

-- ─── Trip Permissions: Performance Indexes ────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_trip_permissions_user_status
  ON public.trip_permissions (user_id, status);

CREATE INDEX IF NOT EXISTS idx_trip_permissions_guardian_status
  ON public.trip_permissions (guardian_id, status);

CREATE INDEX IF NOT EXISTS idx_trip_permissions_end_time
  ON public.trip_permissions (end_time)
  WHERE status = 'active';

-- ─── Trip Permissions: Enable Realtime ────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'trip_permissions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_permissions;
  END IF;
END
$$;

-- ─── Trip Permissions: Auto-Expire Trigger ────────────────────────────────
-- Fungsi untuk auto-complete sesi hangout yang sudah lewat end_time
CREATE OR REPLACE FUNCTION public.fn_auto_expire_trip_permissions()
RETURNS trigger AS $$
BEGIN
  -- Saat ada query SELECT pada trip_permissions, tandai sesi yang sudah expired
  IF NEW.status = 'active' AND NEW.end_time < NOW() THEN
    NEW.status := 'completed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger BEFORE UPDATE untuk auto-expire
DROP TRIGGER IF EXISTS trg_auto_expire_trip ON public.trip_permissions;
CREATE TRIGGER trg_auto_expire_trip
  BEFORE UPDATE ON public.trip_permissions
  FOR EACH ROW
  WHEN (OLD.status = 'active')
  EXECUTE FUNCTION public.fn_auto_expire_trip_permissions();

-- ─── Chat Requests: Performance Index ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_chat_requests_receiver_status
  ON public.chat_requests (receiver_id, status);

CREATE INDEX IF NOT EXISTS idx_chat_requests_sender_status
  ON public.chat_requests (sender_id, status);

-- ─── Chat Requests: Enable Realtime ──────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'chat_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_requests;
  END IF;
END
$$;
