-- ============================================================================
-- MEKAAR 3.0 Migration 63: Clean Orphan & Empty Chat Requests
--
-- 1. Bersihkan rekor chat_requests yang tidak valid (sender = receiver).
-- 2. Isi catatan undangan kosong/whitespace dengan deskripsi default.
-- 3. Hapus rekor duplikat pending ke penerima yang sama (sisakan yang terbaru).
-- ============================================================================

BEGIN;

-- 1. Hapus permintaan diri sendiri ke diri sendiri (invalid)
DELETE FROM public.chat_requests
WHERE sender_id = receiver_id;

-- 2. Normalisasi catatan undangan yang kosong / hanya whitespace
UPDATE public.chat_requests
SET invitation_note = 'Ingin terhubung dan memulai obrolan dengan Anda.'
WHERE invitation_note IS NULL OR TRIM(invitation_note) = '';

-- 3. Hapus rekor duplikat pending (sisakan satu yang paling baru per pasangan sender-receiver)
DELETE FROM public.chat_requests a
USING public.chat_requests b
WHERE a.id < b.id
  AND a.sender_id = b.sender_id
  AND a.receiver_id = b.receiver_id
  AND a.status = 'pending'
  AND b.status = 'pending';

COMMIT;
