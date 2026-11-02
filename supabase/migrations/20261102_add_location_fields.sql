-- =========================================================================
-- AutoDetailCraft: Structured Location & GPS Fields Migration
-- Migration: 20261102_add_location_fields.sql
--
-- Why this is needed:
-- 1. Extends public.profiles with structured address fields for:
--    - Personal Client Home Address (street_address, unit_or_apt, city, state, postal_code, latitude, longitude)
--    - Commercial Studio Address (studio_street_address, studio_unit_or_apt, studio_city, studio_state, studio_postal_code, studio_latitude, studio_longitude)
-- 2. Extends public.bookings with client_unit_or_gate_code, latitude, and longitude for high-precision turn-by-turn detailer navigation.
-- 3. Adds B-tree indexes for zero-cost Explore city & postal code searching.
-- 4. Ensures Realtime replica identity and reloads PostgREST schema cache.
-- =========================================================================

-- 1. EXTEND PUBLIC.PROFILES WITH STRUCTURED LOCATION COLUMNS
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS street_address text DEFAULT '',
  ADD COLUMN IF NOT EXISTS unit_or_apt text DEFAULT '',
  ADD COLUMN IF NOT EXISTS city text DEFAULT '',
  ADD COLUMN IF NOT EXISTS state text DEFAULT '',
  ADD COLUMN IF NOT EXISTS postal_code text DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS studio_street_address text DEFAULT '',
  ADD COLUMN IF NOT EXISTS studio_unit_or_apt text DEFAULT '',
  ADD COLUMN IF NOT EXISTS studio_city text DEFAULT '',
  ADD COLUMN IF NOT EXISTS studio_state text DEFAULT '',
  ADD COLUMN IF NOT EXISTS studio_postal_code text DEFAULT '',
  ADD COLUMN IF NOT EXISTS studio_latitude double precision,
  ADD COLUMN IF NOT EXISTS studio_longitude double precision;

-- 2. CREATE SEARCH INDEXES FOR ZERO-COST EXPLORE SEARCH
CREATE INDEX IF NOT EXISTS idx_profiles_city 
  ON public.profiles (city);

CREATE INDEX IF NOT EXISTS idx_profiles_postal_code 
  ON public.profiles (postal_code);

CREATE INDEX IF NOT EXISTS idx_profiles_studio_city 
  ON public.profiles (studio_city);

CREATE INDEX IF NOT EXISTS idx_profiles_studio_postal_code 
  ON public.profiles (studio_postal_code);

-- 3. EXTEND PUBLIC.BOOKINGS WITH GATE CODE & EXACT GPS COORDINATES
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS client_address text DEFAULT '',
  ADD COLUMN IF NOT EXISTS client_unit_or_gate_code text DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

-- 4. REALTIME REPLICA IDENTITY SAFEGUARD
ALTER TABLE IF EXISTS public.profiles REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.bookings REPLICA IDENTITY FULL;

-- 5. REALTIME PUBLICATION REGISTRATION
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 6. RELOAD SCHEMA CACHE FOR POSTGREST
NOTIFY pgrst, 'reload schema';
