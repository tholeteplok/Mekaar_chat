-- Migration 17: Auto-delete (disappearing messages) enforcement
-- Additive only - safe to run on existing databases.
-- 1) auto_delete_default_hours on profiles (global default for new messages)
-- 2) purge_expired_messages() RPC that hard-deletes messages past auto_delete_at
-- 3) optional pg_cron schedule (guarded; skipped if extension unavailable)

-- ─────────────────────────────────────────
-- 1. Global default for disappearing messages
-- ─────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS auto_delete_default_hours INTEGER NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────
-- 2. Purge function (hard delete expired messages)
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.purge_expired_messages()
RETURNS INTEGER AS $function$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.messages
  WHERE auto_delete_at IS NOT NULL
    AND auto_delete_at < now();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$function$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.purge_expired_messages() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_messages() TO authenticated;

-- ─────────────────────────────────────────
-- 3. Optional scheduled purge via pg_cron (skipped if unavailable)
-- ─────────────────────────────────────────
DO $migration$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron'
  ) THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    -- Run purge every 15 minutes. Safe to re-run; job name guards duplicates.
    IF EXISTS (
      SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cron'
    ) AND NOT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'purge_expired_messages_job'
    ) THEN
      PERFORM cron.schedule(
        'purge_expired_messages_job',
        '*/15 * * * *',
        $command$SELECT public.purge_expired_messages();$command$
      );
    END IF;
  END IF;
END
$migration$;
