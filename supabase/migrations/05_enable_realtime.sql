-- Re-enable publication for realtime tables in an idempotent way
alter publication supabase_realtime drop table if exists public.messages;
alter publication supabase_realtime drop table if exists public.location_pings;
alter publication supabase_realtime drop table if exists public.sos_sessions;

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.location_pings;
alter publication supabase_realtime add table public.sos_sessions;
