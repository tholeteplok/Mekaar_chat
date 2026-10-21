-- Migration 95: Fix RLS policies for sos_sessions to allow active guardians to SELECT active sessions.
-- Membuka blokir pada Supabase Realtime broadcast dan query getActiveSessionsForMe() bagi Guardian aktif.

DROP POLICY IF EXISTS "Users can manage own SOS sessions" ON public.sos_sessions;
DROP POLICY IF EXISTS "Users and guardians can view SOS sessions" ON public.sos_sessions;
DROP POLICY IF EXISTS "Guardians can view assigned active SOS sessions" ON public.sos_sessions;

-- 1. Pemilik akun memiliki kontrol penuh atas sesi miliknya (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Users can manage own SOS sessions" ON public.sos_sessions
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Guardian aktif dapat membaca sesi SOS aktif dari pengguna yang menjadikannya guardian
CREATE POLICY "Guardians can view assigned active SOS sessions" ON public.sos_sessions
  FOR SELECT TO authenticated
  USING (
    status = 'active' AND EXISTS (
      SELECT 1 FROM public.guardians AS g
      WHERE g.owner_id = sos_sessions.user_id
        AND g.guardian_id = auth.uid()
        AND g.status = 'active'
    )
  );
