-- ==============================================================================
-- Migration: 50_fix_auto_checkin_persistent_state.sql
--
-- Mendukung perombakan fitur Auto Check-In Rute:
--   - Status siklus (arrivedAuto/arrivedConfirmed/delayedWarned/dst) sekarang
--     disimpan permanen di sini, MENGGANTIKAN Map di memori yang dulu dipakai
--     GeofenceService & DelayedCheckInService (hilang tiap restart app,
--     berisiko kirim pesan duplikat ke Guardian).
--   - recurrence_days mendukung rute yang cuma berlaku hari tertentu
--     (mis. "Pulang Kerja" cuma Senin-Jumat), bukan cuma tiap hari.
-- ==============================================================================

ALTER TABLE public.user_trips
  ADD COLUMN IF NOT EXISTS recurrence_days INTEGER[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'arrivedAuto', 'arrivedConfirmed', 'delayedWarned', 'delayedAlerted', 'snoozed')),
  ADD COLUMN IF NOT EXISTS active_date DATE,
  ADD COLUMN IF NOT EXISTS last_triggered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS snoozed_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_user_trips_active_monitoring
  ON public.user_trips (user_id, is_active)
  WHERE is_active = true;
