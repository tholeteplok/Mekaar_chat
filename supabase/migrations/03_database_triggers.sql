-- Helper function to update updated_at
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_profiles_modtime ON profiles;
CREATE TRIGGER update_profiles_modtime BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

DROP TRIGGER IF EXISTS update_guardians_modtime ON guardians;
CREATE TRIGGER update_guardians_modtime BEFORE UPDATE ON guardians FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

DROP TRIGGER IF EXISTS update_messages_modtime ON messages;
CREATE TRIGGER update_messages_modtime BEFORE UPDATE ON messages FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

DROP TRIGGER IF EXISTS update_push_tokens_modtime ON push_tokens;
CREATE TRIGGER update_push_tokens_modtime BEFORE UPDATE ON push_tokens FOR EACH ROW EXECUTE PROCEDURE update_modified_column();


-- Trigger function for logging SOS events
CREATE OR REPLACE FUNCTION log_sos_activity()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO security_logs (user_id, event_type, details)
        VALUES (
            NEW.user_id, 
            'sos_started', 
            jsonb_build_object(
                'session_id', NEW.id,
                'started_at', NEW.started_at,
                'gps_enabled', NEW.gps_enabled,
                'mic_enabled', NEW.mic_enabled
            )
        );
    ELSIF (TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status != 'active') THEN
        INSERT INTO security_logs (user_id, event_type, details)
        VALUES (
            NEW.user_id, 
            'sos_ended', 
            jsonb_build_object(
                'session_id', NEW.id,
                'ended_at', NEW.ended_at,
                'ended_reason', NEW.ended_reason,
                'status', NEW.status
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_log_sos_activity ON sos_sessions;
CREATE TRIGGER tr_log_sos_activity
AFTER INSERT OR UPDATE ON sos_sessions
FOR EACH ROW EXECUTE FUNCTION log_sos_activity();


-- Trigger function for logging message deletions
CREATE OR REPLACE FUNCTION log_message_deletion()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.is_deleted = false AND NEW.is_deleted = true) THEN
        INSERT INTO security_logs (user_id, event_type, details)
        VALUES (
            NEW.sender_id, 
            'message_deleted', 
            jsonb_build_object(
                'message_id', NEW.id,
                'room_id', NEW.room_id,
                'deleted_at', now(),
                'description', 'Pesan dihapus oleh pengguna'
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_log_message_deletion ON messages;
CREATE TRIGGER tr_log_message_deletion
AFTER UPDATE ON messages
FOR EACH ROW EXECUTE FUNCTION log_message_deletion();


-- Trigger function to log deletion of security logs (soft-delete logging)
CREATE OR REPLACE FUNCTION log_security_log_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- When a log is deleted (physically or soft deleted by setting a deleted_at)
    -- We log that the user has cleared a security log.
    IF (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL) THEN
        -- Insertion trigger will log the action into logs
        INSERT INTO security_logs (user_id, event_type, details)
        VALUES (
            OLD.user_id,
            'log_deleted',
            jsonb_build_object(
                'deleted_log_id', OLD.id,
                'deleted_event_type', OLD.event_type,
                'deleted_at', now(),
                'description', 'Pengguna menghapus log akses ' || OLD.event_type
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_log_security_log_delete ON security_logs;
CREATE TRIGGER tr_log_security_log_delete
AFTER UPDATE ON security_logs
FOR EACH ROW EXECUTE FUNCTION log_security_log_delete();


-- 12. Trigger to automatically create a profile when a new user signs up in auth.users
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
