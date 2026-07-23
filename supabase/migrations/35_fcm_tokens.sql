-- Migration 35: FCM Device Token Storage & Push Notification Helpers

-- Add fcm_token column to profiles table if not exists
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ;

-- RPC untuk memperbarui FCM Device Token pengguna aktif
CREATE OR REPLACE FUNCTION public.update_fcm_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET 
    fcm_token = p_token,
    fcm_token_updated_at = NOW()
  WHERE id = auth.uid();
END;
$$;

-- Grant EXECUTE permission to authenticated users
GRANT EXECUTE ON FUNCTION public.update_fcm_token(TEXT) TO authenticated;
