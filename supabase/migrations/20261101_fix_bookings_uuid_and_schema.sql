-- =========================================================================
-- AutoDetailCraft: Fix Bookings Table Schema & Permissive Access
-- Migration: 20261101_fix_bookings_uuid_and_schema.sql
-- =========================================================================

-- 1. DROP RESTRICTIVE FOREIGN KEY CONSTRAINTS
ALTER TABLE IF EXISTS public.bookings
  DROP CONSTRAINT IF EXISTS bookings_detailer_id_fkey,
  DROP CONSTRAINT IF EXISTS bookings_client_id_fkey;

-- 2. CONVERT UUID COLUMNS TO TEXT TO SUPPORT GUEST & MOCK IDENTIFIERS
ALTER TABLE IF EXISTS public.bookings
  ALTER COLUMN detailer_id TYPE text USING detailer_id::text,
  ALTER COLUMN client_id TYPE text USING client_id::text;

-- 3. ENSURE RELAXED NULL CONSTRAINTS & COMPATIBILITY COLUMNS
ALTER TABLE IF EXISTS public.bookings
  ALTER COLUMN client_id DROP NOT NULL,
  ALTER COLUMN client_email DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS package jsonb,
  ADD COLUMN IF NOT EXISTS location_type text,
  ADD COLUMN IF NOT EXISTS package_data jsonb,
  ADD COLUMN IF NOT EXISTS service_location_type text;

-- Relax NOT NULL on legacy package_data and service_location_type if present
DO $$
BEGIN
  ALTER TABLE public.bookings ALTER COLUMN package_data DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.bookings ALTER COLUMN service_location_type DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. CLEAN UP AND STANDARDIZE PERMISSIVE RLS POLICIES
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_public" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_authenticated" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_participant" ON public.bookings;
DROP POLICY IF EXISTS "bookings_delete_participant" ON public.bookings;
DROP POLICY IF EXISTS "Allow read on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow insert on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow update on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow delete on bookings" ON public.bookings;

CREATE POLICY "Allow read on bookings" ON public.bookings FOR SELECT USING (true);
CREATE POLICY "Allow insert on bookings" ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on bookings" ON public.bookings FOR UPDATE USING (true);
CREATE POLICY "Allow delete on bookings" ON public.bookings FOR DELETE USING (true);

-- 5. REALTIME REPLICA IDENTITY FULL & PUBLICATION
ALTER TABLE IF EXISTS public.bookings REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 6. RELOAD POSTGREST SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
