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

-- 1. Profiles Policies
CREATE POLICY "Users can manage own profile" ON profiles
  USING (auth.uid() = id);

CREATE POLICY "Users can search other profiles" ON profiles
  FOR SELECT USING (true); -- needed to search other users to add as guardian

-- 2. Guardians Policies
CREATE POLICY "Users can manage own guardian relations" ON guardians
  USING (auth.uid() = owner_id OR auth.uid() = guardian_id);

-- 3. Chat Rooms Policies
CREATE POLICY "Users can view rooms they are in" ON chat_rooms
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM room_participants
      WHERE room_id = chat_rooms.id AND profile_id = auth.uid()
    )
  );

-- 4. Room Participants Policies
CREATE POLICY "Participants can view other room members" ON room_participants
  USING (
    EXISTS (
      SELECT 1 FROM room_participants AS rp
      WHERE rp.room_id = room_participants.room_id AND rp.profile_id = auth.uid()
    )
  );

-- 5. Messages Policies
CREATE POLICY "Users can read/write messages in their rooms" ON messages
  USING (
    EXISTS (
      SELECT 1 FROM room_participants
      WHERE room_id = messages.room_id AND profile_id = auth.uid()
    )
  );

-- 6. SOS Sessions Policies
CREATE POLICY "Users can manage own SOS sessions" ON sos_sessions
  USING (auth.uid() = user_id OR auth.uid() = guardian_id);

-- 7. Location Pings Policies
-- Users can view their own location pings, and active guardians can view location pings during active sessions
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
CREATE POLICY "Users can manage own logs" ON security_logs
  USING (auth.uid() = user_id);

-- 9. Push Tokens Policies
CREATE POLICY "Users can manage own push tokens" ON push_tokens
  USING (auth.uid() = user_id);
