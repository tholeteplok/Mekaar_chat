-- ==============================================================================
-- Migration: 47_fix_calls_table_busy_and_duration.sql
--
-- Memperbarui constraint status tabel 'calls' agar mendukung status 'busy',
-- serta menambahkan kolom started_at, ended_at, dan duration_seconds
-- untuk pencatatan durasi panggilan secara presisi.
-- ==============================================================================

BEGIN;

-- 1. Tambahkan kolom started_at, ended_at, dan duration_seconds jika belum ada
ALTER TABLE public.calls
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS duration_seconds INT DEFAULT 0;

-- 2. Hapus constraint lama calls_status_check jika ada
ALTER TABLE public.calls DROP CONSTRAINT IF EXISTS calls_status_check;

-- 3. Pasang constraint status baru yang menyertakan 'busy'
ALTER TABLE public.calls ADD CONSTRAINT calls_status_check
  CHECK (status IN ('ringing', 'answered', 'declined', 'busy', 'missed', 'ended', 'failed'));

COMMIT;
