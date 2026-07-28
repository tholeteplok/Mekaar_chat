-- Migration 37: Auto Check-In & Geofence Trips Schema

CREATE TABLE IF NOT EXISTS public.user_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    origin_label TEXT,
    destination_label TEXT NOT NULL,
    destination_lat DOUBLE PRECISION NOT NULL,
    destination_lng DOUBLE PRECISION NOT NULL,
    radius_meters INT NOT NULL DEFAULT 150,
    expected_time TIME,
    grace_period_minutes INT NOT NULL DEFAULT 30,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabel relasi guardian penerima check-in
CREATE TABLE IF NOT EXISTS public.trip_guardians (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.user_trips(id) ON DELETE CASCADE,
    guardian_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    delay_minutes INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(trip_id, guardian_id)
);

-- Indeks performa
CREATE INDEX IF NOT EXISTS idx_user_trips_user_id ON public.user_trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_guardians_trip_id ON public.trip_guardians(trip_id);

-- Enable RLS
ALTER TABLE public.user_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_guardians ENABLE ROW LEVEL SECURITY;

-- Policies user_trips
CREATE POLICY "Pengguna dapat mengelola trip milik sendiri"
    ON public.user_trips FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policies trip_guardians
CREATE POLICY "Pengguna dapat mengelola guardian trip milik sendiri"
    ON public.trip_guardians FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_trips
            WHERE id = trip_guardians.trip_id AND user_id = auth.uid()
        )
    );
