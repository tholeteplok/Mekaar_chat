-- ============================================================================
-- MEKAAR 3.0 Migration 105: Fix Profile Column Update Permissions
-- Memulihkan hak UPDATE untuk seluruh kolom operasional profil pengguna
-- ============================================================================

-- Berikan izin UPDATE pada seluruh kolom non-istimewa yang dapat diubah
-- oleh pengguna biasa secara mandiri dari aplikasi (termasuk updated_at).
GRANT UPDATE (
  display_name,
  full_name,
  avatar_url,
  bio,
  updated_at,
  last_seen_at,
  last_seen_privacy,
  read_receipts_enabled,
  chat_invitation_mode,
  auto_delete_default_hours,
  fcm_token,
  fcm_token_updated_at,
  is_device_lost,
  lock_screen_message,
  recovery_contact,
  username,
  username_last_changed_at,
  e2ee_public_key,
  e2ee_key_backup,
  e2ee_key_updated_at,
  pin_hash,
  duress_pin_hash,
  duress_enabled
) ON public.profiles TO authenticated;

-- Pastikan izin SELECT pada profiles tetap dapat diakses oleh authenticated
GRANT SELECT ON public.profiles TO authenticated;
