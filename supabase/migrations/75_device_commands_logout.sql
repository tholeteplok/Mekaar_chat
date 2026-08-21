-- ==============================================================================
-- Migration: 75_device_commands_logout.sql
--
-- Menambahkan command_type 'logout' pada tabel device_commands
-- agar sesi login pada perangkat yang dikeluarkan dapat diputuskan secara remote (F12).
-- ==============================================================================

BEGIN;

-- Perbarui CHECK constraint command_type untuk menyertakan 'logout'
ALTER TABLE public.device_commands
  DROP CONSTRAINT IF EXISTS device_commands_command_type_check;

ALTER TABLE public.device_commands
  ADD CONSTRAINT device_commands_command_type_check
  CHECK (command_type IN ('lock', 'alarm', 'stop_alarm', 'locate', 'logout'));

COMMIT;
