-- =========================================================================
-- AutoDetailCraft: Garage Realtime Sync, Replica Identity & Extended Fields
-- Migration: 20261027_garage_realtime_and_sync.sql
--
-- Why this is needed:
-- 1. Adds missing columns (paint_code, last_detail_service, last_detail_date)
--    so vehicle upserts succeed without PostgREST PGRST204 column errors.
-- 2. REPLICA IDENTITY FULL ensures Postgres Realtime emits the complete old
--    record on DELETE events so client listeners receive user_id on deletions.
-- 3. Adds public.vehicles to supabase_realtime publication for instant cross-device sync.
-- 4. Ensures clean, permissive Row Level Security (RLS) policies for garage vehicles.
-- 5. Signals PostgREST to reload schema cache.
--
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project
-- 3. Click "SQL Editor" in the left sidebar
-- 4. Click "New Query", paste this entire script, and click "Run"
-- =========================================================================

-- 1. EXTEND VEHICLES TABLE COLUMNS
ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS paint_code text DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_detail_service text DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_detail_date text DEFAULT '';

-- 2. REPLICA IDENTITY FULL FOR REALTIME DELETE PAYLOADS
ALTER TABLE IF EXISTS public.vehicles REPLICA IDENTITY FULL;

-- 3. REALTIME PUBLICATION REGISTRATION
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. ROW LEVEL SECURITY POLICIES FOR VEHICLES
ALTER TABLE IF EXISTS public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view vehicles for discovery/bookings." ON public.vehicles;
DROP POLICY IF EXISTS "Users can insert their own vehicles." ON public.vehicles;
DROP POLICY IF EXISTS "Users can update their own vehicles." ON public.vehicles;
DROP POLICY IF EXISTS "Users can delete their own vehicles." ON public.vehicles;
DROP POLICY IF EXISTS "Allow read on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow insert on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow update on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow delete on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_select_policy" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_insert_policy" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_update_policy" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_delete_policy" ON public.vehicles;

CREATE POLICY "Allow read on vehicles" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "Allow insert on vehicles" ON public.vehicles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on vehicles" ON public.vehicles FOR UPDATE USING (true);
CREATE POLICY "Allow delete on vehicles" ON public.vehicles FOR DELETE USING (true);

-- 5. RELOAD SCHEMA CACHE FOR POSTGREST
NOTIFY pgrst, 'reload schema';
