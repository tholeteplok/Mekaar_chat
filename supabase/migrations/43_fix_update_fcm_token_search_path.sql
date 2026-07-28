-- 43_fix_update_fcm_token_search_path.sql
-- Fix: tambahkan SET search_path untuk konsistensi security hardening.
-- Semua RPC SECURITY DEFINER lain di project sudah punya SET search_path = public.
-- Migration 35 (35_fcm_tokens.sql) tidak mencantumkannya.

CREATE OR REPLACE FUNCTION public.update_fcm_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET
    fcm_token = p_token,
    fcm_token_updated_at = NOW()
  WHERE id = auth.uid();
END;
$$;
