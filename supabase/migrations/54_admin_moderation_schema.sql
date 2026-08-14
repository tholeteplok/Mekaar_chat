-- ============================================================================
-- MEKAAR 3.0 Migration 54: Admin Moderation Engine & Safety Guard Schema
-- ============================================================================

-- 1. Tambahkan kolom status suspensi & legal hold pada public.profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_suspended boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS suspension_reason text,
  ADD COLUMN IF NOT EXISTS legal_hold_active boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS legal_hold_case_ref text;

-- 2. Fungsi Helper RLS untuk Pengecekan User Aktif (Instant HTTP 403 Lockout)
CREATE OR REPLACE FUNCTION public.is_user_active()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND (is_suspended IS FALSE OR is_suspended IS NULL)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 3. Tabel Pelaporan Pengguna (public.user_reports)
CREATE TABLE IF NOT EXISTS public.user_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.chat_rooms(id) ON DELETE SET NULL,
  message_id uuid REFERENCES public.messages(id) ON DELETE SET NULL,
  category text NOT NULL CHECK (category IN ('spam', 'harassment', 'fake_sos', 'impersonation', 'other')),
  reason text NOT NULL,
  evidence_snapshot text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Policy RLS user_reports: User hanya bisa melihat laporan buatannya sendiri
CREATE POLICY user_reports_select_own ON public.user_reports
  FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id AND public.is_user_active());

CREATE POLICY user_reports_insert_own ON public.user_reports
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id AND public.is_user_active());

-- 4. Tabel Admin Audit Log Immutable (Append-Only)
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  action_type text NOT NULL CHECK (action_type IN ('SUSPEND', 'UNSUSPEND', 'ENABLE_LEGAL_HOLD', 'DISABLE_LEGAL_HOLD', 'PURGE')),
  target_user_id uuid NOT NULL REFERENCES auth.users(id),
  reason text NOT NULL,
  ip_address text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy RLS Append-Only: Dilarang UPDATE atau DELETE untuk siapa pun (Immutable)
CREATE RULE no_update_admin_audit_logs AS ON UPDATE TO public.admin_audit_logs DO INSTEAD NOTHING;
CREATE RULE no_delete_admin_audit_logs AS ON DELETE TO public.admin_audit_logs DO INSTEAD NOTHING;

-- 5. Stored Procedure Pengajuan Laporan Pengguna (dengan Rate Limiting & Verification)
CREATE OR REPLACE FUNCTION public.submit_user_report(
  p_reported_user_id uuid,
  p_category text,
  p_reason text,
  p_room_id uuid DEFAULT NULL,
  p_message_id uuid DEFAULT NULL,
  p_evidence_snapshot text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_report_id uuid;
BEGIN
  -- Rate limiting: Maksimal 5 laporan per jam per akun
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_rate_limit') THEN
    PERFORM public.check_rate_limit(
      p_user_id := auth.uid(),
      p_action := 'submit_report',
      p_max_requests := 5,
      p_window_seconds := 3600
    );
  END IF;

  -- Verifikasi message_id jika dilampirkan
  IF p_message_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.messages
      WHERE id = p_message_id AND sender_id = p_reported_user_id
    ) THEN
      RAISE EXCEPTION 'INVALID_EVIDENCE: Pesan yang dilaporkan tidak valid atau tidak cocok dengan pengirim.';
    END IF;
  END IF;

  INSERT INTO public.user_reports (
    reporter_id,
    reported_user_id,
    room_id,
    message_id,
    category,
    reason,
    evidence_snapshot
  ) VALUES (
    auth.uid(),
    p_reported_user_id,
    p_room_id,
    p_message_id,
    p_category,
    p_reason,
    p_evidence_snapshot
  ) RETURNING id INTO v_report_id;

  RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6. Stored Procedure Moderasi Admin: Suspend User (dengan SOS Active Immunity Guard)
CREATE OR REPLACE FUNCTION public.admin_suspend_user(
  p_target_user_id uuid,
  p_reason text,
  p_admin_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  v_admin_id := COALESCE(p_admin_id, auth.uid());

  -- IMPERATIVE GUARD: Cek Imunitas Sesi SOS Aktif Korban
  IF EXISTS (
    SELECT 1 FROM public.sos_sessions
    WHERE user_id = p_target_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'SUSPEND_BLOCKED: Pengguna target sedang dalam Sesi Darurat SOS Aktif. Tindakan pembekuan diblokir demi keselamatan jiwa.';
  END IF;

  -- Update status suspensi pada profiles
  UPDATE public.profiles
  SET is_suspended = true,
      suspended_at = NOW(),
      suspension_reason = p_reason
  WHERE id = p_target_user_id;

  -- Catat aksi ke admin_audit_logs
  INSERT INTO public.admin_audit_logs (
    admin_id,
    action_type,
    target_user_id,
    reason
  ) VALUES (
    v_admin_id,
    'SUSPEND',
    p_target_user_id,
    p_reason
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
