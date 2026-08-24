-- ============================================================================
-- MEKAAR 3.0 Migration 79: Fix Missing GRANT on get_nearby_friends
-- ============================================================================
-- Migration 78 membuat function get_nearby_friends tetapi belum memberikan
-- GRANT EXECUTE ke role authenticated, menyebabkan error 403 Forbidden /
-- permission denied bagi pengguna terotentikasi.
--
-- Issue: Nearby Friends tidak menampilkan data meskipun semua kondisi terpenuhi.
-- Root Cause: Role authenticated tidak memiliki hak eksekusi pada RPC function.
-- Fix: Berikan izin eksekusi eksplisit kepada role authenticated.
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.get_nearby_friends(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
