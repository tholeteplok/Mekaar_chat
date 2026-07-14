-- Re-create the supabase_realtime publication to enable Realtime for messages, location pings, and SOS sessions
DROP PUBLICATION IF EXISTS supabase_realtime;

CREATE PUBLICATION supabase_realtime FOR TABLE public.messages, public.location_pings, public.sos_sessions;
