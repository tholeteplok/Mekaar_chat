-- ==============================================================================
-- Migration: 73_device_commands.sql
--
-- Remote Command Framework (F7 + F10 audit fix):
-- Antrian perintah jarak jauh (alarm, lock, locate, stop_alarm)
-- dari pemilik akun ke perangkat miliknya (Device Lost Mode),
-- atau dari Guardian aktif ke perangkat korban SOS (Remote Siren).
-- ==============================================================================

BEGIN;

-- ── 1. Tabel device_commands ──
CREATE TABLE IF NOT EXISTS public.device_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_device_id TEXT,            -- NULL = semua device target_profile_id
  command_type TEXT NOT NULL CHECK (command_type IN ('lock', 'alarm', 'stop_alarm', 'locate')),
  payload JSONB DEFAULT '{}'::jsonb,
  sender_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'executed', 'failed', 'expired')),
  created_at TIMESTAMPTZ DEFAULT now(),
  executed_at TIMESTAMPTZ
);

-- Index
CREATE INDEX IF NOT EXISTS idx_device_commands_target
  ON public.device_commands(target_profile_id, status);
CREATE INDEX IF NOT EXISTS idx_device_commands_created
  ON public.device_commands(created_at DESC);

-- ── 2. RLS ──
ALTER TABLE public.device_commands ENABLE ROW LEVEL SECURITY;

-- Target bisa melihat command yang ditujukan untuk dirinya
CREATE POLICY "Target can view own commands"
  ON public.device_commands FOR SELECT TO authenticated
  USING (target_profile_id = auth.uid());

-- Sender bisa melihat command yang dia kirim
CREATE POLICY "Sender can view sent commands"
  ON public.device_commands FOR SELECT TO authenticated
  USING (sender_profile_id = auth.uid());

-- Otorisasi INSERT command:
-- 1. Mengirim ke diri sendiri (Device Lost Mode: user kirim ke HP-nya yang hilang)
-- 2. Mengirim ke ward (Guardian: membunyikan sirine darurat di HP korban SOS)
CREATE POLICY "Authorized senders can insert commands"
  ON public.device_commands FOR INSERT TO authenticated
  WITH CHECK (
    sender_profile_id = auth.uid()
    AND (
      target_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.guardians g
        WHERE g.guardian_id = auth.uid()
          AND g.owner_id = target_profile_id
          AND g.status = 'active'
      )
    )
  );

-- Target bisa update status command (misal: 'executed', 'failed')
CREATE POLICY "Target can update command status"
  ON public.device_commands FOR UPDATE TO authenticated
  USING (target_profile_id = auth.uid())
  WITH CHECK (target_profile_id = auth.uid());

-- Service role full access
CREATE POLICY "Service role full access to device_commands"
  ON public.device_commands FOR ALL TO service_role
  USING (true);

-- ── 3. Database Trigger untuk Push Notification ──
-- Saat baris baru di-insert ke device_commands, kirim webhook ke Edge Function
DROP TRIGGER IF EXISTS on_device_command_insert_push_notify ON public.device_commands;
CREATE TRIGGER on_device_command_insert_push_notify
  AFTER INSERT ON public.device_commands
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_webhook();

COMMIT;
