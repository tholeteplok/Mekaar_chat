-- ==============================================================================
-- Migration: 40_fix_room_participant_rpcs_search_path.sql
--
-- Bug: "Pengaturan Pesan Menghilang hilang lagi di Contact Settings, dan
--       Chat Screen terkunci di 1 jam (tidak bisa diubah)."
--
-- Akar masalah: migrasi 24 (dan "perbaikan"-nya di migrasi 38, yang hanya
-- membetulkan nama kolom user_id -> profile_id) MENDEFINISIKAN ULANG tiga
-- RPC ini dengan `SET search_path = ''` (search_path KOSONG), TAPI badan
-- fungsinya masih menulis `room_participants` TANPA kualifikasi skema
-- (seharusnya `public.room_participants`).
--
-- Dengan search_path kosong, PostgreSQL TIDAK mencari skema apa pun secara
-- implisit untuk identifier yang tidak memakai prefix skema. Akibatnya
-- setiap kali salah satu dari ketiga RPC ini dipanggil, PostgreSQL gagal
-- me-resolve `room_participants` dan melempar error
-- "relation room_participants does not exist" -- SETIAP KALI, tanpa
-- kecuali, sejak migrasi 24 pertama kali diterapkan.
--
-- Karena `ChatRepository.updateRoomMute()` dan
-- `ChatRepository.updateRoomDisappearingOverride()` di sisi Dart membungkus
-- pemanggilan RPC ini dengan `catch (_) {}` (menelan semua error diam-diam),
-- kegagalan ini tidak pernah terlihat oleh pengguna maupun developer lewat
-- UI biasa -- yang tampak hanyalah "pengaturan tidak pernah benar-benar
-- tersimpan": UI lokal ter-update optimis sesaat, tapi nilai di database
-- TIDAK PERNAH BERUBAH. Efeknya:
--   - Contact Settings, yang selalu membaca ulang dari database saat
--     dibuka, tampak "kehilangan" pengaturan yang baru saja diatur di Chat
--     Screen (karena memang tidak pernah tersimpan).
--   - Chat Screen tampak "terkunci" pada nilai yang SUDAH TERLANJUR
--     tersimpan sebelumnya (atau fallback), karena percobaan mengubahnya
--     ke pilihan lain tidak pernah berhasil.
--
-- Perbaikan: definisikan ulang ketiga RPC dengan `SET search_path = public`
-- -- pola yang SAMA dan SUDAH TERBUKTI benar dipakai oleh RPC lain di
-- seluruh project ini (lihat migrations/05_security_hardening.sql,
-- migrations/08_presence.sql, dst).
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION toggle_room_mute(p_room_id UUID, p_muted BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE room_participants
  SET is_muted = p_muted,
      muted_until = CASE WHEN p_muted THEN NULL ELSE muted_until END
  WHERE room_id = p_room_id
    AND profile_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION mute_room_for_hours(p_room_id UUID, p_hours INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE room_participants
  SET is_muted = TRUE,
      muted_until = CASE
        WHEN p_hours = 0 THEN NULL
        ELSE NOW() + (p_hours || ' hours')::INTERVAL
      END
  WHERE room_id = p_room_id
    AND profile_id = auth.uid();
END;
$$;

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

  UPDATE room_participants
  SET disappearing_override_hours = NULLIF(p_hours, 0)
  WHERE room_id = p_room_id
    AND profile_id = auth.uid();
END;
$$;

COMMIT;

-- Catatan verifikasi manual pasca-migrasi (jalankan di SQL Editor sebagai
-- pengguna yang sudah login/via RPC dari app, BUKAN sebagai superuser,
-- supaya auth.uid() terisi benar):
--   select set_room_disappearing_override('<room_id>', 24);
--   select disappearing_override_hours from room_participants
--     where room_id = '<room_id>' and profile_id = auth.uid();
-- Harus menunjukkan 24, bukan error ataupun tetap NULL.
