-- 06_username_identity.sql
-- Upsert-safe trigger for new user profile creation
-- Ensures username from auth metadata is persisted to profiles table
-- even if the trigger fires after an existing profile row exists.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email, pin_hash)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email,
    ''
  )
  ON CONFLICT (id) DO UPDATE SET
    username = COALESCE(
      EXCLUDED.username,
      profiles.username,
      split_part(EXCLUDED.email, '@', 1)
    ),
    email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
