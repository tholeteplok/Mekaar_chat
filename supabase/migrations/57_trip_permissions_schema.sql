-- ============================================================================
-- MEKAAR 3.0 Migration 57: Trip Permission (Hangout Temporary Share) Schema
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.trip_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  guardian_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  destination_name text NOT NULL,
  start_time timestamptz NOT NULL DEFAULT NOW(),
  end_time timestamptz NOT NULL,
  ping_interval_minutes int DEFAULT 5,
  reminder_15m_enabled boolean DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled_by_user')),
  last_lat double precision,
  last_lon double precision,
  last_ping_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.trip_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trip_permissions_select_participant ON public.trip_permissions;
CREATE POLICY trip_permissions_select_participant ON public.trip_permissions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = guardian_id);

DROP POLICY IF EXISTS trip_permissions_insert_owner ON public.trip_permissions;
CREATE POLICY trip_permissions_insert_owner ON public.trip_permissions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS trip_permissions_update_participant ON public.trip_permissions;
CREATE POLICY trip_permissions_update_participant ON public.trip_permissions
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = guardian_id);
