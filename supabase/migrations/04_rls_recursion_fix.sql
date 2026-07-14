-- 1. Security Definer helper to bypass recursion in RLS check for room participants
CREATE OR REPLACE FUNCTION public.is_room_participant(room_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = room_uuid AND profile_id = user_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update Chat Rooms Policies
DROP POLICY IF EXISTS "Users can view rooms they are in" ON chat_rooms;
CREATE POLICY "Users can view rooms they are in" ON chat_rooms
  FOR SELECT USING (
    public.is_room_participant(id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert chat rooms" ON chat_rooms;
CREATE POLICY "Users can insert chat rooms" ON chat_rooms
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Update Room Participants Policies
DROP POLICY IF EXISTS "Participants can view other room members" ON room_participants;
CREATE POLICY "Participants can view other room members" ON room_participants
  FOR SELECT USING (
    public.is_room_participant(room_id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert room participants" ON room_participants;
CREATE POLICY "Users can insert room participants" ON room_participants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Update Messages Policies
DROP POLICY IF EXISTS "Users can read/write messages in their rooms" ON messages;
CREATE POLICY "Users can read/write messages in their rooms" ON messages
  USING (
    public.is_room_participant(room_id, auth.uid())
  );

-- 5. Trigger to automatically create a profile when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email, pin_hash)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email,
    '' -- empty PIN initially
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
