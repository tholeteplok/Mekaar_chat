-- Migration 36: Enable Webhooks Schema & Helper Function

CREATE SCHEMA IF NOT EXISTS supabase_functions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Helper function supabase_functions.http_request() yang dipanggil oleh UI Database Webhooks
CREATE OR REPLACE FUNCTION supabase_functions.http_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  request_id bigint;
  payload jsonb;
  url text := TG_ARGV[0];
  method text := TG_ARGV[1];
  headers jsonb := TG_ARGV[2]::jsonb;
  params jsonb := TG_ARGV[3]::jsonb;
  timeout int := TG_ARGV[4]::int;
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::jsonb END,
    'old_record', CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END
  );

  SELECT net.http_post(
    url := url,
    headers := headers,
    body := payload,
    timeout_milliseconds := timeout
  ) INTO request_id;

  RETURN NEW;
END;
$$;

GRANT ALL ON SCHEMA supabase_functions TO postgres, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA supabase_functions TO postgres, service_role;
