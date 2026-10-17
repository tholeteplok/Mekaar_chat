-- ==============================================================================
-- Migration: 88_add_calling_status_to_calls.sql
--
-- Menambahkan status 'calling' ke constraint tabel 'calls' dan memperbarui
-- kebijakan RLS agar mendukung Two-Way Handshake ACK:
-- 1. Penelepon membuat panggilan dengan status 'calling' (Memanggil...)
-- 2. Penerima mengonfirmasi dengan status 'ringing' (Berdering...) saat layar aktif
-- ==============================================================================

BEGIN;

-- 1. Hapus constraint status lama calls_status_check
ALTER TABLE public.calls DROP CONSTRAINT IF EXISTS calls_status_check;

-- 2. Pasang constraint status baru yang menyertakan 'calling'
ALTER TABLE public.calls ADD CONSTRAINT calls_status_check
  CHECK (status IN ('calling', 'ringing', 'answered', 'declined', 'busy', 'missed', 'ended', 'failed'));

-- 3. Perbarui RLS insert policy untuk mengizinkan status 'calling' dan 'ringing'
DROP POLICY IF EXISTS "Allow callers to insert calls" ON public.calls;

CREATE POLICY "Allow callers to insert calls" ON public.calls
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = caller_id
    AND status IN ('calling', 'ringing')
  );

-- 4. Perbarui RLS update policy untuk mengizinkan transisi status
DROP POLICY IF EXISTS "Allow participants to update calls" ON public.calls;

CREATE POLICY "Allow participants to update calls" ON public.calls
  FOR UPDATE TO authenticated
  USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  )
  WITH CHECK (
    (
      auth.uid() = caller_id 
      AND status IN ('calling', 'ringing', 'answered', 'ended', 'missed', 'failed', 'busy')
    )
    OR (
      auth.uid() = receiver_id 
      AND status IN ('calling', 'ringing', 'answered', 'declined', 'ended', 'busy', 'failed')
    )
  );

COMMIT;
