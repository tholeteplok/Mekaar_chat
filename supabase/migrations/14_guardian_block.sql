-- 14. Panic Unlink / Break Guardian
-- Pemilik bisa memutus guardian secara instan dan memblokir
-- undangan balik dari guardian tersebut selama 24 jam (cooldown).

ALTER TABLE guardians ADD COLUMN IF NOT EXISTS blocked_until TIMESTAMPTZ;
ALTER TABLE guardians ADD COLUMN IF NOT EXISTS broken_by_owner BOOLEAN DEFAULT FALSE;
