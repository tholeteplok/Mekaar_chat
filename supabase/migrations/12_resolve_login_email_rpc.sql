-- Migration 12: RPC to resolve email from username for login (accessible by anon role)
-- Needed because login happens before authentication, so RLS on profiles blocks direct queries.

CREATE OR REPLACE FUNCTION public.resolve_login_email(input_query TEXT)
RETURNS TEXT AS $$
DECLARE
  result_email TEXT;
BEGIN
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

-- Grant to both anon (pre-login) and authenticated
REVOKE ALL ON FUNCTION public.resolve_login_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO authenticated;
