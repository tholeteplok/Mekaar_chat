-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  pin_locked_until TIMESTAMPTZ,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure profiles has all columns we need if the table already existed
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- 3. Guardian relationships
CREATE TABLE IF NOT EXISTS guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  guardian_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  permissions JSONB NOT NULL DEFAULT '{"gps": false, "mic": false, "video": false}',
  storage_option TEXT DEFAULT 'stream_only',
  status TEXT DEFAULT 'pending', -- pending / active / expired
  expires_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(owner_id, guardian_id)
);

-- 4. Chat rooms
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type TEXT NOT NULL CHECK (room_type IN ('normal', 'guardian', 'self_device')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Room participants
CREATE TABLE IF NOT EXISTS room_participants (
  room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  last_read_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (room_id, profile_id)
);

-- 6. Messages
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT,
  media_url TEXT,
  msg_type TEXT DEFAULT 'text' CHECK (msg_type IN ('text', 'image', 'voice', 'video', 'system', 'location')),
  is_view_once BOOLEAN DEFAULT FALSE,
  reply_to_id UUID REFERENCES messages(id) NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  auto_delete_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. SOS Sessions
CREATE TABLE IF NOT EXISTS sos_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  guardian_id UUID REFERENCES profiles(id) NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'ended', 'auto_ended')),
  gps_enabled BOOLEAN DEFAULT true,
  mic_enabled BOOLEAN DEFAULT false,
  video_enabled BOOLEAN DEFAULT false,
  ended_reason TEXT CHECK (ended_reason IN ('manual', 'timer', 'inactivity')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Location pings
CREATE TABLE IF NOT EXISTS location_pings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sos_sessions(id) ON DELETE CASCADE,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  accuracy DECIMAL(5,2),
  timestamp TIMESTAMPTZ DEFAULT now()
);

-- 9. Security logs (PERMANENT)
CREATE TABLE IF NOT EXISTS security_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ NULL
);

-- 10. Push tokens
CREATE TABLE IF NOT EXISTS push_tokens (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device TEXT DEFAULT 'mobile',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 11. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_location_pings_session_id ON location_pings(session_id);
CREATE INDEX IF NOT EXISTS idx_sos_sessions_user_id ON sos_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_security_logs_user_id ON security_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_guardians_owner_id ON guardians(owner_id);
CREATE INDEX IF NOT EXISTS idx_guardians_guardian_id ON guardians(guardian_id);
CREATE INDEX IF NOT EXISTS idx_room_participants_profile_id ON room_participants(profile_id);
