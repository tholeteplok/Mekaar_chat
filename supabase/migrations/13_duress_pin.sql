-- 13. Duress PIN (PIN Paksaan)
-- PIN terpisah yang, bila dimasukkan saat dipaksa pelaku,
-- membuka aplikasi secara normal namun diam-diam memicu SOS silent.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS duress_pin_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS duress_enabled BOOLEAN DEFAULT FALSE;
