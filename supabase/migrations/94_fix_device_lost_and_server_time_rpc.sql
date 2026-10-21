-- ==============================================================================
-- Migration: 94_fix_device_lost_and_server_time_rpc.sql
--
-- 1. Menambahkan kolom anti-maling (device lost state) pada tabel profiles
--    agar sinkronisasi cloud saat remote lock / hilang tersimpan dengan benar.
-- 2. Menyediakan fungsi RPC get_server_time() untuk verifikasi waktu server (UTC)
--    yang aman dari manipulasi jam lokal perangkat saat PIN lockout.
-- ==============================================================================

BEGIN;

-- 1. Tambah kolom device lost state pada profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_device_lost BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lock_screen_message TEXT,
  ADD COLUMN IF NOT EXISTS recovery_contact TEXT;

-- 2. Fungsi RPC get_server_time()
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT clock_timestamp();
$$;

-- Berikan izin eksekusi ke role authenticated dan anon (untuk keperluan auth/lockout)
GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_server_time() TO anon;

COMMIT;
