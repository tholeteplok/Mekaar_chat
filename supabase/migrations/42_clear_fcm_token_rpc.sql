-- 42_clear_fcm_token_rpc.sql
-- RPC untuk menghapus FCM token saat logout.
-- Mencegah push diterima di perangkat setelah user logout/berganti akun.

BEGIN;

CREATE OR REPLACE FUNCTION public.clear_fcm_token()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = NULL,
      fcm_token_updated_at = NOW()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_fcm_token() TO authenticated;

COMMIT;
