-- ==============================================================================
-- Migration: 51_view_once_opened_state.sql
--
-- Mendukung perbaikan fitur Media Sekali Lihat (View Once Media):
--   - Menambahkan kolom `is_opened` dan `opened_at` pada tabel `public.messages`.
--   - Menambahkan RPC `mark_view_once_opened` agar penerima pesan dapat
--     memperbarui status media sekali lihat menjadi 'dibuka' secara terverifikasi.
-- ==============================================================================

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS is_opened BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS opened_at TIMESTAMPTZ;

-- RPC untuk memperbarui status media sekali lihat yang sudah dibuka
CREATE OR REPLACE FUNCTION public.mark_view_once_opened(target_message_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.messages
  SET is_opened = TRUE,
      opened_at = now()
  WHERE id = target_message_id
    AND is_view_once = TRUE
    AND is_opened = FALSE;
END;
$$;
