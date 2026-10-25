-- Migration 101: Add Ed25519 Safety Signature fields to location_pings table
-- Digunakan untuk verifikasi kriptografi telemetri darurat SOS (Anti-Spoofing Guardian Signature)

ALTER TABLE location_pings 
ADD COLUMN IF NOT EXISTS signature TEXT,
ADD COLUMN IF NOT EXISTS public_key TEXT,
ADD COLUMN IF NOT EXISTS canonical_payload TEXT;

COMMENT ON COLUMN location_pings.signature IS 'Tanda tangan digital Ed25519 Base64 yang dihasilkan di native Aegis Core';
COMMENT ON COLUMN location_pings.public_key IS 'Kunci publik Ed25519 Base64 untuk verifikasi penerima / Guardian';
COMMENT ON COLUMN location_pings.canonical_payload IS 'String paket darurat kanonikal (MEKAAR_SOS_V1:userId:timestamp:lat:lng:type)';
