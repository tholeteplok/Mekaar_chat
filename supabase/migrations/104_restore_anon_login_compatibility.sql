-- ============================================================================
-- MEKAAR 3.0 Migration 104: Restore Anon Access to resolve_login_email
-- Memulihkan kompatibilitas alur login username dan reset password
-- ============================================================================

-- Berikan kembali hak eksekusi resolve_login_email kepada peran anon dan authenticated
-- agar pengguna pra-login dapat memetakan username ke email akun mereka.
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon, authenticated;
