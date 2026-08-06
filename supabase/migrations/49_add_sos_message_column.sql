-- Migration 49: Menambahkan kolom message ke sos_sessions untuk digunakan di push notification.

ALTER TABLE public.sos_sessions
ADD COLUMN IF NOT EXISTS message TEXT;
