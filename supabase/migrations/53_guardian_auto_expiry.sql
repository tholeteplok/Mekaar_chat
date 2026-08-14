-- Migration 53: Auto-expire pending guardian invitations after 7 days
CREATE OR REPLACE FUNCTION expire_old_guardian_invites()
RETURNS trigger AS $$
BEGIN
  UPDATE guardians
  SET status = 'expired', updated_at = now()
  WHERE status = 'pending' AND created_at < now() - INTERVAL '7 days';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to run auto-expiry check on queries/updates
DROP TRIGGER IF EXISTS trg_expire_old_guardian_invites ON guardians;
CREATE TRIGGER trg_expire_old_guardian_invites
  AFTER INSERT OR UPDATE ON guardians
  FOR EACH STATEMENT
  EXECUTE FUNCTION expire_old_guardian_invites();
