-- 15. Log Cryptographic Signing (Blind Spot #5)
-- Menandatangani ekspor Log Sistem (SHA-256) via Edge Function `sign-logs`
-- agar berkas bukti hukum tidak dapat diubah tanpa merusak tanda tangan.
--
-- Edge Function di-deploy terpisah (supabase/functions/sign-logs):
--   supabase functions deploy sign-logs
-- Migrasi ini hanya mencatat kebijakan akses & memastikan kolom yang
-- dibutuhkan function sudah ada. Tidak ada perubahan skema wajib.

-- Pastikan security_logs memiliki indeks untuk ekspor cepat (idempoten).
CREATE INDEX IF NOT EXISTS idx_security_logs_user_created
  ON security_logs (user_id, created_at DESC);

-- Catatan: function `sign-logs` berjalan di Deno runtime (Supabase Edge
-- Functions) dan membaca security_logs dengan RLS user yang memanggilnya.
-- Tidak perlu GRANT tambahan karena function memakai Auth header pemanggil.
