-- Migration 48: Add active_days to user_trips for recurring day filtering (1=Mon, 7=Sun)

ALTER TABLE public.user_trips
ADD COLUMN IF NOT EXISTS active_days INT[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}';
