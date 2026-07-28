-- ==============================================================================
-- Migration: 44_fix_disappearing_and_lint_hardening.sql
--
-- Tiga perbaikan independen dalam satu migrasi:
--   A. Bug fungsional: "Pesan Menghilang" kembali ke 1 jam setelah diset "Mati"
--   B. Hardening: search_path mutable pada 4 fungsi (lint WARN)
--   C. Hardening: banyak RPC bisa dieksekusi role `anon` karena grant PUBLIC
--      default Postgres tidak pernah di-REVOKE (lint WARN, 35 fungsi)
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------
-- A. FIX BUG: set_room_disappearing_override menyimpan "Mati" (0) sebagai
--    NULL lewat NULLIF(p_hours, 0) -- yang di kode Dart berarti "belum ada
--    override, ikuti fallback global". Akibatnya, memilih "Mati" pada chat
--    manapun langsung "collapse" jadi status global begitu layar chat
--    ditutup dan dibuka lagi. Perbaikan: simpan p_hours apa adanya (0 tetap
--    0, bukan NULL) -- lihat migrations/40_fix_room_participant_rpcs_
--    search_path.sql untuk riwayat perbaikan RPC ini sebelumnya.
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_room_disappearing_override(p_room_id UUID, p_hours INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_hours < 0 THEN
    RAISE EXCEPTION 'disappearing hours tidak boleh negatif';
  END IF;

  -- p_hours disimpan APA ADANYA. 0 = "Mati" (state eksplisit, valid),
  -- BUKAN NULL. NULL hanya untuk baris yang memang belum pernah diatur
  -- sama sekali (default kolom saat participant baru dibuat).
  UPDATE room_participants
  SET disappearing_override_hours = p_hours
  WHERE room_id = p_room_id
    AND profile_id = auth.uid();
END;
$$;

COMMIT;

-- Catatan sisi Dart (lihat perubahan terpisah di chat_screen.dart &
-- contact_settings_screen.dart pada commit ini): karena 0 sekarang
-- tersimpan sebagai 0 (bukan NULL), fallback lama
--   `preferences?.disappearingOverrideHours ?? globalAutoDelete`
-- sebenarnya sudah cukup untuk memperbaiki bug "Mati" -- tapi sesuai
-- arahan "tidak ada pengaturan global", fallback ke `globalAutoDelete`
-- (profile.auto_delete_default_hours) DIHAPUS SEPENUHNYA dari kedua
-- layar tersebut. Provider `autoDeleteDefaultProvider` yang sudah tidak
-- terpakai di UI mana pun juga dihapus. Sekarang NULL (baris yang belum
-- pernah diatur sama sekali) diperlakukan identik dengan 0 ("Mati") --
-- murni per-room, tidak ada konsep global sama sekali.


-- ------------------------------------------------------------------------
-- B. HARDENING: search_path mutable pada 4 fungsi (lint WARN).
--    Sudah diverifikasi manual: keempatnya TIDAK punya bug fungsional
--    aktif (semua referensi tabel sudah/atau tidak perlu prefix skema).
--    Ini murni defense-in-depth, bukan perbaikan bug.
-- ------------------------------------------------------------------------
ALTER FUNCTION public.update_modified_column() SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.set_screenshot_protection_updated_at() SET search_path = public;
ALTER FUNCTION public.create_group_room(text, text, text, uuid[]) SET search_path = public;


-- ------------------------------------------------------------------------
-- C. HARDENING: revoke EXECUTE dari PUBLIC (mencakup role `anon`) untuk
--    RPC yang tidak seharusnya dipanggil oleh siapa pun yang belum login.
--
--    Postgres otomatis memberi EXECUTE ke PUBLIC saat fungsi dibuat,
--    KECUALI di-REVOKE eksplisit -- ini berlaku terlepas dari ada
--    tidaknya `GRANT ... TO authenticated` belakangan (GRANT menambah,
--    tidak menghapus grant PUBLIC yang sudah ada). Makanya 35 RPC di
--    project ini tetap muncul sebagai "bisa dieksekusi anon" di linter
--    Supabase walau sebagian sudah punya GRANT eksplisit ke authenticated.
--
--    Fungsi-fungsi ini sebagian besar sudah AMAN secara fungsional (semua
--    melakukan `IF auth.uid() IS NULL THEN RAISE EXCEPTION` di awal, atau
--    berupa fungsi trigger yang memang tidak bisa dipanggil manual sama
--    sekali) -- REVOKE di sini adalah defense-in-depth, bukan menutup
--    eksploitasi yang sudah terbukti ada, KECUALI untuk check_rate_limit
--    (lihat catatan khusus di bawah, yang itu genuinely exploitable).
-- ------------------------------------------------------------------------

-- C.1 -- Fungsi yang HANYA boleh dipanggil oleh pengguna yang sudah login.
--        Revoke dari PUBLIC & anon, pastikan tetap granted ke authenticated.
DO $$
DECLARE
  fn TEXT;
  fns TEXT[] := ARRAY[
    'accept_guardian_invite(uuid)',
    'clear_fcm_token()',
    'create_group_room(text, text, text, uuid[])',
    'delete_message_for_everyone(uuid)',
    'disable_2fa()',
    'enable_2fa(text)',
    'get_last_seen_for(uuid)',
    'get_or_create_direct_room(uuid, text)',
    'get_or_create_direct_room(uuid, text, boolean)',
    'hide_message_for_me(uuid)',
    'invite_guardian(uuid, uuid, jsonb)',
    'is_blocked_by_me(uuid)',
    'is_room_participant(uuid, uuid)',
    'log_sos_event(uuid, text, jsonb)',
    'mark_room_read(uuid)',
    'mute_room_for_hours(uuid, integer)',
    'preview_invite_token(text)',
    'record_login_device(text)',
    'redeem_invite_token(text, jsonb)',
    'rotate_invite_token()',
    'search_public_profiles(text)',
    'set_room_disappearing_override(uuid, integer)',
    'soft_delete_message(uuid)',
    'toggle_reaction(uuid, text)',
    'toggle_room_mute(uuid, boolean)',
    'update_fcm_token(text)',
    'update_last_seen()'
  ];
BEGIN
  FOREACH fn IN ARRAY fns LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%s FROM PUBLIC, anon;', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated;', fn);
  END LOOP;
END $$;

-- C.2 -- Fungsi TRIGGER: tidak bisa dipanggil manual oleh siapa pun lewat
--        SQL biasa (Postgres menolak `SELECT fn()` atas fungsi RETURNS
--        TRIGGER), jadi grant EXECUTE di sini murni kosmetik/tidak
--        eksploitable. Tetap di-revoke untuk kebersihan & konsistensi
--        lint, tidak ada risiko meng-break apa pun karena trigger
--        dieksekusi dengan hak function OWNER, bukan lewat grant PUBLIC.
DO $$
DECLARE
  fn TEXT;
  fns TEXT[] := ARRAY[
    'handle_new_user()',
    'handle_new_message_restore_rooms()',
    'notify_push_webhook()',
    'log_sos_activity()'
  ];
BEGIN
  FOREACH fn IN ARRAY fns LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%s FROM PUBLIC, anon, authenticated;', fn);
  END LOOP;
END $$;

-- C.3 -- Fungsi maintenance/cron: seharusnya TIDAK diekspos ke client sama
--        sekali (baik anon maupun authenticated) -- hanya boleh dipanggil
--        terjadwal (pg_cron) atau manual oleh admin lewat SQL Editor
--        (yang berjalan sebagai superuser/owner, tidak butuh grant PUBLIC).
DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION public.cleanup_expired_sos_audit() FROM PUBLIC, anon, authenticated;
  REVOKE EXECUTE ON FUNCTION public.purge_expired_messages() FROM PUBLIC, anon, authenticated;
END $$;

-- C.4 -- check_rate_limit: PALING PENTING dari semua revoke di atas, ini
--        BUKAN sekadar hardening kosmetik. p_max_attempts & p_interval
--        diterima sebagai PARAMETER dari pemanggil, bukan konstanta yang
--        di-hardcode server-side. Selama masih EXECUTE-able publik,
--        siapa pun bisa memanggil endpoint /rest/v1/rpc/check_rate_limit
--        langsung dengan p_max_attempts besar & p_interval sangat pendek
--        untuk (a) melumpuhkan rate limit miliknya sendiri, dan/atau
--        (b) menyisipkan banyak baris `auth_attempts` palsu atas nama
--        p_caller siapa pun (mis. email korban) sehingga rate limit ASLI
--        (5/menit, di-hardcode di resolve_login_email/enable_2fa/dst)
--        langsung habis dan korban ter-DoS saat mencoba login/2FA yang
--        sah. Fungsi ini HANYA dipanggil secara internal (PERFORM) oleh
--        resolve_login_email/enable_2fa/disable_2fa/record_login_device
--        -- revoke ini TIDAK memutus pemanggilan internal tersebut,
--        karena panggilan antar-fungsi SECURITY DEFINER berjalan di bawah
--        konteks pemilik fungsi, bukan lewat pengecekan grant role REST.
REVOKE EXECUTE ON FUNCTION public.check_rate_limit(text, text, integer, interval)
  FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------------------------------
-- D. HARDENING: storage policy bucket `avatars` terlalu luas --
--    `using (bucket_id = 'avatars')` tanpa syarat lain mengizinkan
--    SIAPA PUN melakukan query SELECT atas seluruh baris `storage.objects`
--    di bucket ini (listing/enumerasi nama file & folder -- yang di sini
--    berarti UUID setiap pengguna yang pernah upload avatar), bukan cuma
--    mengambil satu file yang sudah diketahui path-nya.
--
--    Bucket ini TETAP public (avatar memang harus bisa dilihat siapa saja
--    tanpa login) -- akses ambil-file-per-URL untuk bucket public DILAYANI
--    LEWAT JALUR TERPISAH oleh Supabase Storage (endpoint
--    /storage/v1/object/public/...) yang TIDAK bergantung pada policy RLS
--    `storage.objects` ini sama sekali. Jadi policy SELECT di bawah ini
--    murni soal listing/query tabel, bukan soal bisa-tidaknya avatar
--    tampil di app -- aman dihapus. (Sudah diverifikasi: tidak ada
--    pemanggilan `.storage.from('avatars').list(...)` di kode Dart.)
-- ------------------------------------------------------------------------
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;

-- ------------------------------------------------------------------------
-- Catatan (item lint yang SENGAJA tidak disentuh/tidak bisa lewat SQL):
--
-- - resolve_login_email(text): SENGAJA dibiarkan bisa dieksekusi `anon`
--   -- ini dipakai di layar login SEBELUM ada sesi. Sudah dilindungi rate
--   limit internal (check_rate_limit, 5/menit) sejak migrasi 28.
--
-- - rls_auto_enable(): tidak ditemukan definisinya di migrasi manapun di
--   project ini -- kemungkinan besar fungsi internal Supabase (terkait
--   fitur auto-enable RLS di Table Editor), bukan buatan project. Sengaja
--   TIDAK disentuh di sini karena project mungkin tidak punya kendali/
--   kepemilikan atas definisinya.
--
-- - public_bucket_allows_listing (bucket `avatars`): sudah diperbaiki di
--   bagian D migrasi ini.
--
-- - auth_leaked_password_protection: BUKAN migrasi SQL -- ini toggle di
--   Supabase Dashboard (Authentication > Policies > "Leaked password
--   protection"). Tidak bisa diaktifkan lewat SQL migration.
--   Lihat AUDIT_LINT_SUPABASE.md untuk detail & langkahnya.
-- ------------------------------------------------------------------------
