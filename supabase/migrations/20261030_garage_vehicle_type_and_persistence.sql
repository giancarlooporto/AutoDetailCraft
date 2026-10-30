-- =========================================================================
-- AutoDetailCraft: Garage Vehicle Type Persistence, Profile FK Trigger & Realtime
-- Migration: 20261030_garage_vehicle_type_and_persistence.sql
--
-- Why this is needed:
-- 1. Adds vehicle_type and body_type columns to public.vehicles so PostgREST
--    upserts succeed without PGRST204 missing column errors.
-- 2. Ensures public.profiles row exists on auth user creation via trigger,
--    preventing foreign key 23503 errors when saving garage vehicles.
-- 3. Sets up clean, permissive RLS policies for public.vehicles across read/insert/update/delete.
-- 4. Ensures public.vehicles is in supabase_realtime publication and replica identity full.
-- 5. Signals PostgREST to reload its schema cache.
--
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project
-- 3. Click "SQL Editor" in the left sidebar
-- 4. Click "New Query", paste this entire script, and click "Run"
-- =========================================================================

-- 1. EXTEND VEHICLES TABLE COLUMNS
ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'Sedan',
  ADD COLUMN IF NOT EXISTS body_type text DEFAULT 'Sedan',
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

-- 5. AUTO-CREATE PROFILES TRIGGER ON AUTH USER CREATION (Prevents FK 23503 errors)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1), 'Vehicle Owner'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'client')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Backfill missing profile rows for any existing auth.users
INSERT INTO public.profiles (id, email, display_name, role)
SELECT
  id,
  email,
  COALESCE(raw_user_meta_data->>'display_name', split_part(email, '@', 1), 'Vehicle Owner'),
  COALESCE(raw_user_meta_data->>'role', 'client')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 6. RELOAD SCHEMA CACHE FOR POSTGREST
NOTIFY pgrst, 'reload schema';
