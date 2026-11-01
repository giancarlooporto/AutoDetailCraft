-- =========================================================================
-- AutoDetailCraft: Fix Bookings Table Schema & Permissive Access (CORRECTED ORDER)
-- Migration: 20261101_fix_bookings_uuid_and_schema.sql
-- =========================================================================

-- 1. DYNAMICALLY DROP ALL EXISTING POLICIES ON BOOKINGS FIRST
-- (PostgreSQL blocks altering column types if any RLS policy references them)
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'bookings' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.bookings';
    END LOOP;
END $$;

-- Explicit drops as an extra safeguard
DROP POLICY IF EXISTS "bookings_update_participant" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_public" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_authenticated" ON public.bookings;
DROP POLICY IF EXISTS "bookings_delete_participant" ON public.bookings;
DROP POLICY IF EXISTS "Allow read on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow insert on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow update on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow delete on bookings" ON public.bookings;

-- 2. DROP RESTRICTIVE FOREIGN KEY CONSTRAINTS
ALTER TABLE IF EXISTS public.bookings
  DROP CONSTRAINT IF EXISTS bookings_detailer_id_fkey,
  DROP CONSTRAINT IF EXISTS bookings_client_id_fkey;

-- 3. NOW SAFELY CONVERT UUID COLUMNS TO TEXT TO SUPPORT ALL SESSIONS
ALTER TABLE IF EXISTS public.bookings
  ALTER COLUMN detailer_id TYPE text USING detailer_id::text,
  ALTER COLUMN client_id TYPE text USING client_id::text;

-- 4. ENSURE RELAXED NULL CONSTRAINTS & COMPATIBILITY COLUMNS
ALTER TABLE IF EXISTS public.bookings
  ALTER COLUMN client_id DROP NOT NULL,
  ALTER COLUMN client_email DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS package jsonb,
  ADD COLUMN IF NOT EXISTS location_type text,
  ADD COLUMN IF NOT EXISTS package_data jsonb,
  ADD COLUMN IF NOT EXISTS service_location_type text;

DO $$ BEGIN
  ALTER TABLE public.bookings ALTER COLUMN package_data DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.bookings ALTER COLUMN service_location_type DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 5. RE-CREATE PERMISSIVE RLS POLICIES FOR INSTANT CROSS-DEVICE SYNC
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read on bookings" ON public.bookings FOR SELECT USING (true);
CREATE POLICY "Allow insert on bookings" ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on bookings" ON public.bookings FOR UPDATE USING (true);
CREATE POLICY "Allow delete on bookings" ON public.bookings FOR DELETE USING (true);

-- 6. REALTIME REPLICA IDENTITY FULL & PUBLICATION
ALTER TABLE IF EXISTS public.bookings REPLICA IDENTITY FULL;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';
