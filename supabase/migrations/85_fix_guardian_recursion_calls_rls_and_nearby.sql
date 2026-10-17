-- ==============================================================================
-- MEKAAR 3.0 Migration 85: Fix Guardian Recursion, Calls RLS, and Nearby Ambiguity
--
-- 1. Memperbaiki rekursi tak hingga pada trigger expire_old_guardian_invites() (Error 54001)
--    dengan pg_trigger_depth() <= 1 dan membatasi trigger hanya pada AFTER INSERT.
-- 2. Memperbaiki error RLS 403 / 42501 pada tabel calls saat penerima menjawab ('answered')
--    dengan memindahkan proteksi integritas kolom ke BEFORE UPDATE trigger dan
--    menyederhanakan klausa WITH CHECK pada RLS policy.
-- 3. Memperbaiki error 42702 (column reference "user_id" is ambiguous) pada RPC get_nearby_friends
--    dengan mengoreksi referensi g.owner_id dan menambahkan instruksi #variable_conflict use_column.
-- ==============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. PERBAIKAN TRIGGER GUARDIAN AUTO-EXPIRY (Mencegah Error 54001)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_old_guardian_invites()
RETURNS trigger AS $$
BEGIN
  -- Cegah eksekusi rekursif jika fungsi ini memicu UPDATE di dalam dirinya sendiri
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  UPDATE public.guardians
  SET status = 'expired', updated_at = now()
  WHERE status = 'pending' AND created_at < now() - INTERVAL '7 days';

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Hapus trigger lama dan daftarkan ulang HANYA pada AFTER INSERT (bukan AFTER UPDATE)
DROP TRIGGER IF EXISTS trg_expire_old_guardian_invites ON public.guardians;

CREATE TRIGGER trg_expire_old_guardian_invites
  AFTER INSERT ON public.guardians
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.expire_old_guardian_invites();

-- ----------------------------------------------------------------------------
-- 2. PERBAIKAN RLS & IMMUTABILITY TABEL CALLS (Mencegah Error 42501 saat answered)
-- ----------------------------------------------------------------------------
-- A. Trigger BEFORE UPDATE untuk memastikan caller_id, receiver_id, dan room_id tidak diubah
CREATE OR REPLACE FUNCTION public.check_call_update_immutability()
RETURNS trigger AS $$
BEGIN
  IF NEW.caller_id <> OLD.caller_id OR NEW.receiver_id <> OLD.receiver_id OR NEW.room_id <> OLD.room_id THEN
    RAISE EXCEPTION 'caller_id, receiver_id, and room_id cannot be modified';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_check_call_update_immutability ON public.calls;

CREATE TRIGGER trg_check_call_update_immutability
  BEFORE UPDATE ON public.calls
  FOR EACH ROW
  EXECUTE FUNCTION public.check_call_update_immutability();

-- B. Perbarui policy UPDATE pada tabel calls (tanpa subquery korelatif ke diri sendiri)
DROP POLICY IF EXISTS "Allow participants to update calls" ON public.calls;

CREATE POLICY "Allow participants to update calls" ON public.calls
  FOR UPDATE TO authenticated
  USING (
    caller_id = auth.uid() OR receiver_id = auth.uid()
  )
  WITH CHECK (
    (
      auth.uid() = caller_id 
      AND status IN ('ringing', 'ended', 'missed', 'failed', 'busy')
    )
    OR (
      auth.uid() = receiver_id 
      AND status IN ('ringing', 'answered', 'declined', 'ended', 'busy', 'failed')
    )
  );

-- ----------------------------------------------------------------------------
-- 3. PERBAIKAN RPC get_nearby_friends (Mencegah Error 42702 & g.owner_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_nearby_friends(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    avatar_url TEXT,
    band TEXT,
    is_recent BOOLEAN,
    is_contact BOOLEAN,
    chat_invitation_mode TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
DECLARE
    v_caller_id UUID;
    v_caller_enabled BOOLEAN;
    v_caller_visibility TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN;
    END IF;

    -- 1. Opportunistic Auto-Purge: Hapus semua ping lokasi yang lebih tua dari 1 jam (TTL 1 Jam)
    DELETE FROM public.nearby_location_pings 
    WHERE updated_at < (now() - INTERVAL '1 hour');

    -- 2. Periksa / Inisialisasi preferensi pemanggil jika belum ada
    INSERT INTO public.nearby_sharing_prefs (user_id, enabled, visibility_mode, updated_at)
    VALUES (v_caller_id, true, 'contacts_only', now())
    ON CONFLICT (user_id) DO NOTHING;

    SELECT COALESCE(enabled, true), COALESCE(visibility_mode, 'contacts_only')
    INTO v_caller_enabled, v_caller_visibility
    FROM public.nearby_sharing_prefs
    WHERE nearby_sharing_prefs.user_id = v_caller_id;

    -- Jika pemanggil secara eksplisit menonaktifkan fitur, keluar (zero data)
    IF v_caller_enabled IS FALSE THEN
        RETURN;
    END IF;

    -- 3. Upsert ping lokasi pemanggil (Single-Row per user, overwrite lokasi lama)
    INSERT INTO public.nearby_location_pings (user_id, latitude, longitude, updated_at)
    VALUES (v_caller_id, p_latitude, p_longitude, now())
    ON CONFLICT (user_id)
    DO UPDATE SET
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = now();

    -- 4. Query pengguna lain yang aktif dalam 1 jam terakhir
    RETURN QUERY
    WITH candidate_locations AS (
        SELECT 
            p.user_id AS target_user_id,
            p.latitude AS target_lat,
            p.longitude AS target_lon,
            p.updated_at AS ping_time,
            COALESCE(prefs.visibility_mode, 'contacts_only') AS target_visibility
        FROM public.nearby_location_pings p
        LEFT JOIN public.nearby_sharing_prefs prefs ON prefs.user_id = p.user_id
        WHERE p.user_id <> v_caller_id
          AND COALESCE(prefs.enabled, true) = true
          AND p.updated_at >= (now() - INTERVAL '1 hour')
    ),
    distance_calculated AS (
        SELECT 
            c.target_user_id,
            c.ping_time,
            c.target_visibility,
            -- Rumus Haversine dalam kilometer (Radius Bumi = 6371 km)
            (
                6371.0 * 2.0 * asin(
                    sqrt(
                        power(sin(radians(c.target_lat - p_latitude) / 2.0), 2.0) +
                        cos(radians(p_latitude)) * cos(radians(c.target_lat)) *
                        power(sin(radians(c.target_lon - p_longitude) / 2.0), 2.0)
                    )
                )
            ) AS dist_km
        FROM candidate_locations c
    ),
    filtered_and_banded AS (
        SELECT 
            d.target_user_id,
            d.ping_time,
            d.target_visibility,
            d.dist_km,
            CASE 
                WHEN d.dist_km < 0.5 THEN 'very_close'
                WHEN d.dist_km <= 2.0 THEN 'close'
                ELSE 'same_city'
            END AS distance_band
        FROM distance_calculated d
        WHERE d.dist_km <= 10.0 -- Filter di luar 10 km
    )
    SELECT 
        prof.id AS user_id,
        COALESCE(prof.display_name, prof.full_name, prof.username, 'Pengguna MEKAAR') AS display_name,
        prof.avatar_url,
        f.distance_band AS band,
        (f.ping_time >= (now() - INTERVAL '15 minutes')) AS is_recent,
        -- Cek status kontak komprehensif: room_participants, accepted chat_requests, atau active guardians
        (
            EXISTS (
                SELECT 1 
                FROM public.room_participants rp1
                JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
                WHERE rp1.profile_id = v_caller_id
                  AND rp2.profile_id = prof.id
            )
            OR EXISTS (
                SELECT 1
                FROM public.chat_requests cr
                WHERE ((cr.sender_id = v_caller_id AND cr.receiver_id = prof.id)
                    OR (cr.sender_id = prof.id AND cr.receiver_id = v_caller_id))
                  AND cr.status = 'accepted'
            )
            OR EXISTS (
                SELECT 1
                FROM public.guardians g
                WHERE ((g.owner_id = v_caller_id AND g.guardian_id = prof.id)
                    OR (g.owner_id = prof.id AND g.guardian_id = v_caller_id))
                  AND g.status = 'active'
            )
        ) AS is_contact,
        COALESCE(prof.chat_invitation_mode, 'all') AS chat_invitation_mode
    FROM filtered_and_banded f
    JOIN public.profiles prof ON prof.id = f.target_user_id
    WHERE 
        -- Filter berdasarkan preferensi visibilitas pemanggil:
        (
            -- Jika pemanggil memilih 'everyone' (Semua): Tampilkan semua pengguna dalam radius 10 km
            v_caller_visibility = 'everyone'
            OR (
                -- Jika pemanggil memilih 'contacts_only' (Kontak): Wajib berstatus kontak
                v_caller_visibility = 'contacts_only'
                AND (
                    EXISTS (
                        SELECT 1 
                        FROM public.room_participants rp1
                        JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
                        WHERE rp1.profile_id = v_caller_id
                          AND rp2.profile_id = prof.id
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM public.chat_requests cr
                        WHERE ((cr.sender_id = v_caller_id AND cr.receiver_id = prof.id)
                            OR (cr.sender_id = prof.id AND cr.receiver_id = v_caller_id))
                          AND cr.status = 'accepted'
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM public.guardians g
                        WHERE ((g.owner_id = v_caller_id AND g.guardian_id = prof.id)
                            OR (g.owner_id = prof.id AND g.guardian_id = v_caller_id))
                          AND g.status = 'active'
                    )
                )
            )
        )
        -- Exclude jika ada blokir (user_blocks)
        AND NOT EXISTS (
            SELECT 1 FROM public.user_blocks ub
            WHERE (ub.blocker_id = v_caller_id AND ub.blocked_id = prof.id)
               OR (ub.blocker_id = prof.id AND ub.blocked_id = v_caller_id)
        )
    ORDER BY 
        f.dist_km ASC,
        f.ping_time DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_friends(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

COMMIT;
