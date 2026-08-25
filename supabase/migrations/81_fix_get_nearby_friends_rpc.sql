-- MEKAAR 3.0 Migration 81: Fix get_nearby_friends RPC Column & Table References
-- 1. Mengoreksi kolom room_participants dari user_id ke profile_id
-- 2. Mengoreksi tabel blokir dari blocked_users ke user_blocks (blocker_id, blocked_id)
-- 3. Memastikan GRANT EXECUTE diberikan ke role authenticated

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

    -- 2. Periksa preferensi pemanggil
    SELECT enabled, visibility_mode
    INTO v_caller_enabled, v_caller_visibility
    FROM public.nearby_sharing_prefs
    WHERE nearby_sharing_prefs.user_id = v_caller_id;

    -- Jika belum terdaftar atau tidak aktif, keluar (zero data)
    IF v_caller_enabled IS NOT TRUE THEN
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

    -- 4. Query pengguna lain yang mutual opt-in dan aktif dalam 1 jam terakhir
    RETURN QUERY
    WITH candidate_locations AS (
        SELECT 
            p.user_id AS target_user_id,
            p.latitude AS target_lat,
            p.longitude AS target_lon,
            p.updated_at AS ping_time,
            prefs.visibility_mode AS target_visibility
        FROM public.nearby_location_pings p
        JOIN public.nearby_sharing_prefs prefs ON prefs.user_id = p.user_id
        WHERE p.user_id <> v_caller_id
          AND prefs.enabled = true
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
        COALESCE(prof.full_name, prof.username, 'Pengguna MEKAAR') AS display_name,
        prof.avatar_url,
        f.distance_band AS band,
        (f.ping_time >= (now() - INTERVAL '15 minutes')) AS is_recent,
        -- Cek apakah mereka sudah saling terhubung di room obrolan (profile_id)
        EXISTS (
            SELECT 1 
            FROM public.room_participants rp1
            JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
            WHERE rp1.profile_id = v_caller_id
              AND rp2.profile_id = prof.id
        ) AS is_contact,
        COALESCE(prof.chat_invitation_mode, 'all') AS chat_invitation_mode
    FROM filtered_and_banded f
    JOIN public.profiles prof ON prof.id = f.target_user_id
    WHERE 
        -- Pengecekan Mutual Visibility:
        (
            -- Jika target kontak-only, maka harus sudah saling kontak
            f.target_visibility = 'everyone'
            OR (
                f.target_visibility = 'contacts_only'
                AND EXISTS (
                    SELECT 1 
                    FROM public.room_participants rp1
                    JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
                    WHERE rp1.profile_id = v_caller_id
                      AND rp2.profile_id = prof.id
                )
            )
        )
        AND (
            -- Jika caller kontak-only, caller juga hanya ingin melihat kontak
            v_caller_visibility = 'everyone'
            OR (
                v_caller_visibility = 'contacts_only'
                AND EXISTS (
                    SELECT 1 
                    FROM public.room_participants rp1
                    JOIN public.room_participants rp2 ON rp1.room_id = rp2.room_id
                    WHERE rp1.profile_id = v_caller_id
                      AND rp2.profile_id = prof.id
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
