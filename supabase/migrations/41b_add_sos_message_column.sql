-- 41b_add_sos_message_column.sql
-- Menambahkan kolom message ke sos_sessions untuk digunakan di push notification.
-- Diperlukan karena 41_sos_push_triggers.sql mengirim data SOS ke guardian.

ALTER TABLE public.sos_sessions
ADD COLUMN IF NOT EXISTS message TEXT;
