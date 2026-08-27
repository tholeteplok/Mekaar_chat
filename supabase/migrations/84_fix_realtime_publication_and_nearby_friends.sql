-- ==============================================================================
-- MEKAAR 3.0 Migration 84: Fix Realtime Publication & Resilient Nearby Friends
-- 
-- 1. Memastikan publikasi supabase_realtime memuat tabel-tabel penting (calls, messages, profiles)
-- 2. Mengaktifkan REPLICA IDENTITY FULL pada tabel calls dan messages
-- 3. Memperbarui RPC get_nearby_friends agar mendukung filter 'Semua' (everyone) dan
--    filter 'Kontak' (room_participants, chat_requests accepted, guardians) secara andal
-- ==============================================================================

BEGIN;

-- 1. Pastikan tabel calls, messages, profiles, nearby_location_pings ada di publikasi Realtime
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_sessions;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2. Set REPLICA IDENTITY FULL agar CDC / filter realtime bekerja sempurna
ALTER TABLE public.calls REPLICA IDENTITY FULL;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.nearby_location_pings REPLICA IDENTITY FULL;
ALTER TABLE public.nearby_sharing_prefs REPLICA IDENTITY FULL;

-- 3. Update RPC get_nearby_friends
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
                WHERE ((g.user_id = v_caller_id AND g.guardian_id = prof.id)
                    OR (g.user_id = prof.id AND g.guardian_id = v_caller_id))
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
                        WHERE ((g.user_id = v_caller_id AND g.guardian_id = prof.id)
                            OR (g.user_id = prof.id AND g.guardian_id = v_caller_id))
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

-- Berikan hak eksekusi ke authenticated user
GRANT EXECUTE ON FUNCTION public.get_nearby_friends(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

COMMIT;
