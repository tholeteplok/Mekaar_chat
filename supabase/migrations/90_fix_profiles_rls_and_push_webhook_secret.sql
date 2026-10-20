-- ============================================================================
-- MEKAAR 3.0 Migration 90: Remediasi P0 Kritis
-- 1. Penutupan Celah Kebocoran Kolom profiles (Strict Own-Row RLS Policy)
-- 2. Pembaruan View public_profiles (Ekspos Kolom Aman + chat_invitation_mode & bio)
-- 3. Pengamanan Webhook Trigger & Edge Function Push Notification via Shared Secret
-- ============================================================================

-- ============================================================================
-- BAGIAN 1: Pengetatan RLS Tabel profiles
-- ============================================================================

-- 1. Drop semua policy SELECT lama yang terlalu longgar (auth.uid() IS NOT NULL)
DROP POLICY IF EXISTS "Authenticated can read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated can read any public profile" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can read active user profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;

-- 2. Pasang policy ketat: User HANYA bisa SELECT baris miliknya sendiri
-- Menutup celah ekstraksi massal pin_hash, duress_pin_hash, two_fa_secret, e2ee_key_backup
CREATE POLICY "Users can only read own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- ============================================================================
-- BAGIAN 2: Rebuild View public_profiles (Hanya Kolom Publik Aman)
-- ============================================================================

DROP VIEW IF EXISTS public.public_profiles;

CREATE VIEW public.public_profiles
WITH (security_barrier = true)
AS
SELECT
  id,
  username,
  full_name,
  display_name,
  avatar_url,
  last_seen_at,
  last_seen_privacy,
  created_at,
  e2ee_public_key,
  chat_invitation_mode,
  bio
FROM public.profiles;

-- Berikan hak SELECT view ke role authenticated dan anon (untuk pencarian profil)
GRANT SELECT ON public.public_profiles TO authenticated;
GRANT SELECT ON public.public_profiles TO anon;

-- ============================================================================
-- BAGIAN 3: Pengamanan Shared Secret Webhook Push Notification
-- ============================================================================

-- 1. Inisialisasi shared secret di tabel public.app_config jika belum ada
INSERT INTO public.app_config (key, value)
VALUES ('push_webhook_secret', 'mk_sec_' || encode(gen_random_bytes(32), 'hex'))
ON CONFLICT (key) DO NOTHING;

-- 2. Perbarui trigger function notify_push_webhook() agar mengirim x-webhook-secret
CREATE OR REPLACE FUNCTION public.notify_push_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  webhook_url text;
  anon_key text;
  webhook_secret text;
  payload jsonb;
  request_id bigint;
BEGIN
  -- 1) Baca konfigurasi URL push dari tabel app_config
  SELECT value INTO webhook_url FROM public.app_config WHERE key = 'push_webhook_url';

  IF webhook_url IS NULL OR webhook_url = '' THEN
    webhook_url := current_setting('app.settings.push_webhook_url', true);
  END IF;

  IF webhook_url IS NULL OR webhook_url = '' THEN
    webhook_url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-push-notification';
  END IF;

  -- Proteksi: Abaikan jika URL kosong atau masih placeholder '<...>'
  IF webhook_url IS NULL OR webhook_url = '' OR webhook_url LIKE '%<%>%' THEN
    RETURN NEW;
  END IF;

  -- 2) Baca anon_key untuk identitas gateway
  SELECT value INTO anon_key FROM public.app_config WHERE key = 'anon_key';
  IF anon_key IS NULL OR anon_key = '' OR anon_key LIKE '%<%>%' THEN
    anon_key := current_setting('app.settings.anon_key', true);
  END IF;

  -- 3) Baca shared secret untuk otentikasi internal webhook
  SELECT value INTO webhook_secret FROM public.app_config WHERE key = 'push_webhook_secret';
  IF webhook_secret IS NULL OR webhook_secret = '' THEN
    webhook_secret := current_setting('app.settings.push_webhook_secret', true);
  END IF;

  -- 4) Bangun payload webhook sesuai format pg_net
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  -- 5) Fail-Safe HTTP POST via pg_net menyertakan x-webhook-secret header
  BEGIN
    SELECT net.http_post(
      url := webhook_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', coalesce(anon_key, ''),
        'x-webhook-secret', coalesce(webhook_secret, '')
      ),
      body := payload,
      timeout_milliseconds := 5000
    ) INTO request_id;

    RAISE NOTICE 'Push webhook sent: request_id=%, table=%', request_id, TG_TABLE_NAME;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Push webhook call failed (table: %, error: %)', TG_TABLE_NAME, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Pastikan service_role memiliki hak eksekusi
GRANT EXECUTE ON FUNCTION public.notify_push_webhook() TO service_role;
