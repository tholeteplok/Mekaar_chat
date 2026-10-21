-- Migration 93: Set default now() untuk started_at pada tabel sos_sessions
-- Menghindari not-null constraint violation jika started_at tidak disertakan secara eksplisit dari client.

BEGIN;

ALTER TABLE public.sos_sessions
  ALTER COLUMN started_at SET DEFAULT now();

COMMIT;
