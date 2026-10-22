-- ==============================================================================
-- Migration: 96_user_contacts_and_username_lock.sql
-- Description:
-- 1. Tabel independen `user_contacts` untuk memisahkan relasi kontak dari kamar chat.
-- 2. Backfill kontak yang sudah ada dari riwayat room_participants.
-- 3. RPC `delete_contact_and_chat` untuk menghapus kontak & membersihkan percakapannya.
-- 4. Kolom `username_last_changed_at` dan RPC `change_username` dengan proteksi cooldown 60 hari.
-- ==============================================================================

-- 1. Buat tabel user_contacts
CREATE TABLE IF NOT EXISTS public.user_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    contact_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    alias_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT user_contacts_user_contact_unique UNIQUE (user_id, contact_user_id),
    CONSTRAINT user_contacts_no_self CHECK (user_id != contact_user_id)
);

-- Indeks untuk pencarian cepat
CREATE INDEX IF NOT EXISTS idx_user_contacts_user_id ON public.user_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_contacts_contact_id ON public.user_contacts(contact_user_id);

-- RLS untuk user_contacts
ALTER TABLE public.user_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own contacts" ON public.user_contacts;
CREATE POLICY "Users can manage own contacts" ON public.user_contacts
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT ALL ON TABLE public.user_contacts TO authenticated;

-- View helper untuk query kontak terenkapsulasi lengkap dengan profile & status guardian
CREATE OR REPLACE VIEW public.user_contacts_view
WITH (security_barrier = true)
AS
SELECT
  c.id,
  c.user_id,
  c.contact_user_id,
  c.alias_name,
  c.created_at,
  p.username,
  p.full_name,
  p.display_name,
  p.avatar_url,
  p.bio,
  EXISTS (
    SELECT 1 FROM public.guardians g
    WHERE (g.owner_id = c.user_id AND g.guardian_id = c.contact_user_id AND g.status = 'active')
       OR (g.guardian_id = c.user_id AND g.owner_id = c.contact_user_id AND g.status = 'active')
  ) AS is_guardian
FROM public.user_contacts c
JOIN public.public_profiles p ON p.id = c.contact_user_id;

GRANT SELECT ON public.user_contacts_view TO authenticated;

-- 2. Backfill kontak eksisting dari riwayat percakapan direct room
INSERT INTO public.user_contacts (user_id, contact_user_id, created_at)
SELECT DISTINCT
    rp1.profile_id AS user_id,
    rp2.profile_id AS contact_user_id,
    COALESCE(rp1.joined_at, now()) AS created_at
FROM public.room_participants rp1
JOIN public.room_participants rp2 
    ON rp1.room_id = rp2.room_id 
   AND rp1.profile_id != rp2.profile_id
JOIN public.chat_rooms cr 
    ON cr.id = rp1.room_id
WHERE cr.room_type IN ('normal', 'guardian')
ON CONFLICT (user_id, contact_user_id) DO NOTHING;

-- 3. Update get_or_create_direct_room agar otomatis mendaftarkan kedua belah pihak ke user_contacts
CREATE OR REPLACE FUNCTION public.get_or_create_direct_room(
  other_user_id UUID,
  requested_room_type TEXT DEFAULT 'normal',
  p_screenshot_protection BOOLEAN DEFAULT TRUE
)
RETURNS UUID AS $$
DECLARE
  current_user_id UUID := auth.uid();
  existing_room_id UUID;
  new_room_id UUID;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF other_user_id IS NULL THEN
    RAISE EXCEPTION 'Other user is required';
  END IF;

  IF current_user_id = other_user_id THEN
    RAISE EXCEPTION 'Cannot create direct room with yourself';
  END IF;

  IF requested_room_type NOT IN ('normal', 'guardian') THEN
    RAISE EXCEPTION 'Unsupported room type: %', requested_room_type;
  END IF;

  -- Pastikan kontak terdaftar di tabel user_contacts untuk inisiator
  INSERT INTO public.user_contacts (user_id, contact_user_id)
  VALUES (current_user_id, other_user_id)
  ON CONFLICT (user_id, contact_user_id) DO NOTHING;

  SELECT rp1.room_id
  INTO existing_room_id
  FROM public.room_participants AS rp1
  JOIN public.room_participants AS rp2
    ON rp2.room_id = rp1.room_id
  JOIN public.chat_rooms AS cr
    ON cr.id = rp1.room_id
  WHERE rp1.profile_id = current_user_id
    AND rp2.profile_id = other_user_id
    AND cr.room_type = requested_room_type
  LIMIT 1;

  IF existing_room_id IS NOT NULL THEN
    -- Restore: ONLY clear deleted_at. NEVER clear history_cleared_at!
    UPDATE public.room_participants
    SET deleted_at = NULL
    WHERE room_id = existing_room_id
      AND profile_id = current_user_id;

    RETURN existing_room_id;
  END IF;

  INSERT INTO public.chat_rooms (room_type)
  VALUES (requested_room_type)
  RETURNING id INTO new_room_id;

  INSERT INTO public.room_participants (room_id, profile_id, screenshot_protection_enabled)
  VALUES
    (new_room_id, current_user_id, p_screenshot_protection),
    (new_room_id, other_user_id, p_screenshot_protection);

  RETURN new_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC untuk Menghapus Kontak Sekaligus Membersihkan Percakapan
CREATE OR REPLACE FUNCTION public.delete_contact_and_chat(p_contact_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_room_id UUID;
  now_iso TIMESTAMPTZ := now();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Hapus dari daftar kontak pengguna pemanggil
  DELETE FROM public.user_contacts
  WHERE user_id = v_caller_id AND contact_user_id = p_contact_user_id;

  -- 2. Cari semua kamar obrolan bilateral (normal / guardian)
  FOR v_room_id IN
    SELECT rp1.room_id
    FROM public.room_participants rp1
    JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
    JOIN public.chat_rooms cr ON cr.id = rp1.room_id
    WHERE rp1.profile_id = v_caller_id
      AND rp2.profile_id = p_contact_user_id
      AND cr.room_type IN ('normal', 'guardian')
  LOOP
    -- Tandai obrolan terhapus dan hapus riwayat untuk pemanggil
    UPDATE public.room_participants
    SET deleted_at = now_iso,
        history_cleared_at = now_iso
    WHERE room_id = v_room_id AND profile_id = v_caller_id;

    -- Sembunyikan pesan di kamar tersebut bagi pemanggil
    INSERT INTO public.hidden_messages (profile_id, message_id)
    SELECT v_caller_id, m.id
    FROM public.messages m
    WHERE m.room_id = v_room_id
    ON CONFLICT (profile_id, message_id) DO NOTHING;
  END LOOP;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_contact_and_chat(UUID) TO authenticated;

-- 5. Tambah kolom username_last_changed_at pada tabel profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username_last_changed_at TIMESTAMPTZ;

-- 6. RPC untuk Mengubah Username dengan Validasi Cooldown 60 Hari
CREATE OR REPLACE FUNCTION public.change_username(p_new_username TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_last_changed TIMESTAMPTZ;
  v_clean_username TEXT;
  v_days_diff INT;
  v_remaining_days INT;
  v_cooldown_days INT := 60;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_clean_username := lower(trim(p_new_username));

  IF length(v_clean_username) < 3 OR length(v_clean_username) > 30 THEN
    RAISE EXCEPTION 'Username harus antara 3 sampai 30 karakter';
  END IF;

  IF v_clean_username !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Username hanya boleh berisi huruf kecil, angka, dan underscore';
  END IF;

  -- Cek keunikan username
  IF EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE username = v_clean_username AND id != v_caller_id
  ) THEN
    RAISE EXCEPTION 'Username sudah digunakan oleh orang lain';
  END IF;

  -- Cek batas waktu (cooldown)
  SELECT username_last_changed_at INTO v_last_changed
  FROM public.profiles
  WHERE id = v_caller_id;

  IF v_last_changed IS NOT NULL THEN
    v_days_diff := EXTRACT(DAY FROM (now() - v_last_changed))::INT;
    IF v_days_diff < v_cooldown_days THEN
      v_remaining_days := v_cooldown_days - v_days_diff;
      IF v_remaining_days <= 0 THEN
        v_remaining_days := 1;
      END IF;
      RAISE EXCEPTION 'Username baru saja diubah. Silakan tunggu % hari lagi.', v_remaining_days;
    END IF;
  END IF;

  -- Update username & timestamp
  UPDATE public.profiles
  SET username = v_clean_username,
      username_last_changed_at = now(),
      updated_at = now()
  WHERE id = v_caller_id;

  RETURN jsonb_build_object(
    'success', true,
    'username', v_clean_username,
    'username_last_changed_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.change_username(TEXT) TO authenticated;
