-- ==============================================================================
-- MEKAAR 3.0 Migration 86: Enable Realtime for Guardians Table
--
-- Menambahkan tabel public.guardians ke publikasi supabase_realtime dan
-- mengaktifkan REPLICA IDENTITY FULL agar perubahan data (undangan guardian baru,
-- persetujuan, penolakan, pemutusan) langsung terkirim secara realtime ke aplikasi.
-- ==============================================================================

BEGIN;

-- 1. Daftarkan tabel guardians ke publikasi supabase_realtime
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.guardians;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2. Aktifkan REPLICA IDENTITY FULL agar payload event DELETE & UPDATE memuat data relasi lengkap
ALTER TABLE public.guardians REPLICA IDENTITY FULL;

COMMIT;
