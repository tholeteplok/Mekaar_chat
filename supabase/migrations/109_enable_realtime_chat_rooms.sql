-- ==============================================================================
-- Migration: 109_enable_realtime_chat_rooms.sql
--
-- Menambahkan tabel public.chat_rooms ke publikasi supabase_realtime
-- agar perubahan pengaturan privasi obrolan (disappearing_hours, burn_on_exit,
-- scheduled_wipe_mode) dapat disinkronkan secara instan (bilateral) ke kedua belah pihak.
-- ==============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'chat_rooms'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
    END IF;
  END IF;
END $$;

ALTER TABLE public.chat_rooms REPLICA IDENTITY FULL;
