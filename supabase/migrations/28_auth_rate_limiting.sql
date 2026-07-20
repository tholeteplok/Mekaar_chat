-- Create a centralized auth attempts tracking table
CREATE TABLE IF NOT EXISTS public.auth_attempts (
  caller TEXT NOT NULL,
  attempt_type TEXT NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup and cleanup
CREATE INDEX IF NOT EXISTS idx_auth_attempts_caller_type
  ON public.auth_attempts (caller, attempt_type, attempted_at DESC);

-- Enable RLS and lock it down
ALTER TABLE public.auth_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auth_attempts FROM PUBLIC, anon, authenticated;

-- Helper function to check and record attempts
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_caller TEXT,
  p_type TEXT,
  p_max_attempts INT,
  p_interval INTERVAL
)
RETURNS VOID AS $$
DECLARE
  v_count INT;
BEGIN
  -- Perform cleanup of records older than 1 hour (background cleanup)
  DELETE FROM public.auth_attempts
  WHERE attempted_at < now() - interval '1 hour';

  -- Count recent attempts within the interval
  SELECT count(*)
  INTO v_count
  FROM public.auth_attempts
  WHERE caller = p_caller
    AND attempt_type = p_type
    AND attempted_at > now() - p_interval;

  -- Raise exception if rate limit exceeded
  IF v_count >= p_max_attempts THEN
    RAISE EXCEPTION 'Terlalu banyak percobaan %, silakan coba lagi nanti.', p_type;
  END IF;

  -- Record the new attempt
  INSERT INTO public.auth_attempts (caller, attempt_type)
  VALUES (p_caller, p_type);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Re-implement resolve_login_email with the centralized rate limiter
CREATE OR REPLACE FUNCTION public.resolve_login_email(input_query TEXT)
RETURNS TEXT AS $$
DECLARE
  result_email TEXT;
  v_caller TEXT;
BEGIN
  v_caller := COALESCE(
    auth.uid()::text,
    nullif(
      split_part(
        COALESCE(current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', ''),
        ',',
        1
      ),
      ''
    ),
    'unknown'
  );

  -- 5 attempts per 1 minute for email resolution
  PERFORM public.check_rate_limit(v_caller, 'resolve_email', 5, interval '1 minute');

  -- If input looks like an email, return it directly
  IF trim(input_query) LIKE '%@%' THEN
    RETURN trim(input_query);
  END IF;

  -- Lookup email by username (case-insensitive exact match)
  SELECT email INTO result_email
  FROM public.profiles
  WHERE lower(username) = lower(trim(input_query))
  LIMIT 1;

  RETURN result_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.resolve_login_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO authenticated;

-- Add rate limiting to enable_2fa
CREATE OR REPLACE FUNCTION public.enable_2fa(secret TEXT)
RETURNS VOID AS $$
DECLARE
  v_caller TEXT;
BEGIN
  IF auth.uid() IS NULL THEN 
    RAISE EXCEPTION 'Unauthorized'; 
  END IF;
  
  v_caller := auth.uid()::text;
  
  -- Limit: 5 attempts per 5 minutes for enabling 2FA (prevent brute-forcing setup)
  PERFORM public.check_rate_limit(v_caller, 'enable_2fa', 5, interval '5 minutes');

  UPDATE public.profiles
  SET two_fa_enabled = true,
      two_fa_secret = secret,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.enable_2fa(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enable_2fa(TEXT) TO authenticated;

-- Add rate limiting to disable_2fa
CREATE OR REPLACE FUNCTION public.disable_2fa()
RETURNS VOID AS $$
DECLARE
  v_caller TEXT;
BEGIN
  IF auth.uid() IS NULL THEN 
    RAISE EXCEPTION 'Unauthorized'; 
  END IF;
  
  v_caller := auth.uid()::text;
  
  -- Limit: 5 attempts per 5 minutes for disabling 2FA
  PERFORM public.check_rate_limit(v_caller, 'disable_2fa', 5, interval '5 minutes');

  UPDATE public.profiles
  SET two_fa_enabled = false,
      two_fa_secret = NULL,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.disable_2fa() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.disable_2fa() TO authenticated;

-- Add rate limiting to record_login_device
CREATE OR REPLACE FUNCTION public.record_login_device(device_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  prev_device TEXT;
  is_new BOOLEAN;
  v_caller TEXT;
BEGIN
  IF auth.uid() IS NULL THEN 
    RETURN FALSE; 
  END IF;

  v_caller := auth.uid()::text;
  
  -- Limit: 10 calls per 1 minute for recording device (prevent flood)
  PERFORM public.check_rate_limit(v_caller, 'record_device', 10, interval '1 minute');

  SELECT last_login_device INTO prev_device
  FROM public.profiles WHERE id = auth.uid();

  is_new := (prev_device IS NULL) OR (prev_device <> device_name);

  UPDATE public.profiles
  SET last_login_device = device_name,
      last_login_at = now(),
      updated_at = now()
  WHERE id = auth.uid();

  RETURN is_new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.record_login_device(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_login_device(TEXT) TO authenticated;
