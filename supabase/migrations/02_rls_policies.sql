-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Security Definer helper to bypass recursion in RLS check for room participants
CREATE OR REPLACE FUNCTION public.is_room_participant(room_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = room_uuid AND profile_id = user_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. Profiles Policies
DROP POLICY IF EXISTS "Users can manage own profile" ON profiles;
CREATE POLICY "Users can manage own profile" ON profiles
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can search other profiles" ON profiles;
CREATE POLICY "Users can search other profiles" ON profiles
  FOR SELECT USING (true); -- needed to search other users to add as guardian

-- 2. Guardians Policies
DROP POLICY IF EXISTS "Users can manage own guardian relations" ON guardians;
CREATE POLICY "Users can manage own guardian relations" ON guardians
  USING (auth.uid() = owner_id OR auth.uid() = guardian_id);

-- 3. Chat Rooms Policies
DROP POLICY IF EXISTS "Users can view rooms they are in" ON chat_rooms;
CREATE POLICY "Users can view rooms they are in" ON chat_rooms
  FOR SELECT USING (
    public.is_room_participant(id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert chat rooms" ON chat_rooms;
CREATE POLICY "Users can insert chat rooms" ON chat_rooms
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Room Participants Policies
DROP POLICY IF EXISTS "Participants can view other room members" ON room_participants;
CREATE POLICY "Participants can view other room members" ON room_participants
  FOR SELECT USING (
    public.is_room_participant(room_id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert room participants" ON room_participants;
CREATE POLICY "Users can insert room participants" ON room_participants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 5. Messages Policies
DROP POLICY IF EXISTS "Users can read/write messages in their rooms" ON messages;
CREATE POLICY "Users can read/write messages in their rooms" ON messages
  USING (
    public.is_room_participant(room_id, auth.uid())
  );

-- 6. SOS Sessions Policies
DROP POLICY IF EXISTS "Users can manage own SOS sessions" ON sos_sessions;
CREATE POLICY "Users can manage own SOS sessions" ON sos_sessions
  USING (auth.uid() = user_id OR auth.uid() = guardian_id);

-- 7. Location Pings Policies
DROP POLICY IF EXISTS "Access location pings during active SOS" ON location_pings;
CREATE POLICY "Access location pings during active SOS" ON location_pings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM sos_sessions AS ss
      WHERE ss.id = location_pings.session_id
      AND (
        ss.user_id = auth.uid() 
        OR (
          ss.status = 'active'
          AND EXISTS (
            SELECT 1 FROM guardians AS g
            WHERE g.owner_id = ss.user_id
            AND g.guardian_id = auth.uid()
            AND g.status = 'active'
            AND (g.permissions->>'gps')::boolean = true
          )
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can insert own location pings" ON location_pings;
CREATE POLICY "Users can insert own location pings" ON location_pings
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM sos_sessions AS ss
      WHERE ss.id = location_pings.session_id
      AND ss.user_id = auth.uid()
      AND ss.status = 'active'
    )
  );

-- 8. Security Logs Policies
DROP POLICY IF EXISTS "Users can manage own logs" ON security_logs;
CREATE POLICY "Users can manage own logs" ON security_logs
  USING (auth.uid() = user_id);

-- 9. Push Tokens Policies
DROP POLICY IF EXISTS "Users can manage own push tokens" ON push_tokens;
CREATE POLICY "Users can manage own push tokens" ON push_tokens
  USING (auth.uid() = user_id);
