-- ============================================================================
-- AutoDetailCraft: Studio Workbench Hub Full Cross-Device Sync Migration
-- Run in Supabase Dashboard -> SQL Editor -> New Query -> Run
-- Idempotent: safe to run multiple times without dropping existing data.
-- ============================================================================

-- 1. PROFILES: Ensure Studio Workbench & handle columns exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS service_packages jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS calendar_preferences jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_studio_paused boolean DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'profiles' AND indexname = 'profiles_username_lower_unique'
  ) THEN
    CREATE UNIQUE INDEX profiles_username_lower_unique
      ON public.profiles (lower(username))
      WHERE username IS NOT NULL AND length(trim(username)) > 0;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow insert on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow update on profiles" ON public.profiles;
CREATE POLICY "Allow read on profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert on profiles" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on profiles" ON public.profiles FOR UPDATE USING (true);

-- 2. JOBS (Portfolio transformations)
CREATE TABLE IF NOT EXISTS public.jobs (
  id text PRIMARY KEY,
  author_id text NOT NULL,
  title text NOT NULL,
  description text DEFAULT '',
  vehicle_year integer,
  vehicle_make text,
  vehicle_model text,
  paint_color text,
  service_type text,
  before_image_url text,
  after_image_url text,
  raw_data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow insert on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow update on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow delete on jobs" ON public.jobs;
CREATE POLICY "Allow read on jobs" ON public.jobs FOR SELECT USING (true);
CREATE POLICY "Allow insert on jobs" ON public.jobs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on jobs" ON public.jobs FOR UPDATE USING (true);
CREATE POLICY "Allow delete on jobs" ON public.jobs FOR DELETE USING (true);

-- 3. TEAM MEMBERS (My Teams)
CREATE TABLE IF NOT EXISTS public.team_members (
  id text PRIMARY KEY,
  studio_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  role_title text NOT NULL DEFAULT 'Detail Specialist',
  avatar_url text DEFAULT '',
  rating numeric DEFAULT 5.0,
  completed_jobs_count integer DEFAULT 0,
  is_available boolean DEFAULT true,
  is_founder boolean DEFAULT false,
  can_edit_inventory boolean DEFAULT true,
  can_view_pricing boolean DEFAULT true,
  can_manage_team boolean DEFAULT false,
  can_view_all_team_calendar boolean DEFAULT true,
  email text,
  pin text,
  invite_token text,
  invite_status text DEFAULT 'none',
  invite_sent_at timestamp with time zone,
  allowed_hub_sections jsonb,
  custom_weekly_schedule jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS is_founder boolean DEFAULT false;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS can_edit_inventory boolean DEFAULT true;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS can_view_pricing boolean DEFAULT true;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS can_manage_team boolean DEFAULT false;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS can_view_all_team_calendar boolean DEFAULT true;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS pin text;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS invite_token text;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS invite_status text DEFAULT 'none';
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS invite_sent_at timestamp with time zone;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS allowed_hub_sections jsonb;
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS custom_weekly_schedule jsonb;

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow insert on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow update on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow delete on team_members" ON public.team_members;
CREATE POLICY "Allow read on team_members" ON public.team_members FOR SELECT USING (true);
CREATE POLICY "Allow insert on team_members" ON public.team_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on team_members" ON public.team_members FOR UPDATE USING (true);
CREATE POLICY "Allow delete on team_members" ON public.team_members FOR DELETE USING (true);

-- 4. INVENTORY ITEMS (Hardware, Chemicals, Recipes)
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id text PRIMARY KEY,
  studio_id text NOT NULL,
  name text NOT NULL,
  category text NOT NULL,
  brand text DEFAULT '',
  sub_category text DEFAULT '',
  status text DEFAULT 'In Service',
  location text DEFAULT '',
  raw_data jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on inventory_items" ON public.inventory_items;
DROP POLICY IF EXISTS "Allow insert on inventory_items" ON public.inventory_items;
DROP POLICY IF EXISTS "Allow update on inventory_items" ON public.inventory_items;
DROP POLICY IF EXISTS "Allow delete on inventory_items" ON public.inventory_items;
CREATE POLICY "Allow read on inventory_items" ON public.inventory_items FOR SELECT USING (true);
CREATE POLICY "Allow insert on inventory_items" ON public.inventory_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on inventory_items" ON public.inventory_items FOR UPDATE USING (true);
CREATE POLICY "Allow delete on inventory_items" ON public.inventory_items FOR DELETE USING (true);

-- 5. AVAILABILITY BLOCKS (Calendar Day/Slot blocks & date overrides)
CREATE TABLE IF NOT EXISTS public.availability_blocks (
  id text PRIMARY KEY,
  detailer_id text NOT NULL,
  team_member_id text,
  date timestamp with time zone NOT NULL,
  is_all_day boolean DEFAULT true,
  blocked_slots jsonb DEFAULT '[]'::jsonb,
  custom_slots jsonb DEFAULT '[]'::jsonb,
  has_custom_slots_override boolean DEFAULT false,
  reason text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.availability_blocks ADD COLUMN IF NOT EXISTS team_member_id text;
ALTER TABLE public.availability_blocks ADD COLUMN IF NOT EXISTS custom_slots jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.availability_blocks ADD COLUMN IF NOT EXISTS has_custom_slots_override boolean DEFAULT false;

ALTER TABLE public.availability_blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow insert on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow update on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow delete on availability_blocks" ON public.availability_blocks;
CREATE POLICY "Allow read on availability_blocks" ON public.availability_blocks FOR SELECT USING (true);
CREATE POLICY "Allow insert on availability_blocks" ON public.availability_blocks FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on availability_blocks" ON public.availability_blocks FOR UPDATE USING (true);
CREATE POLICY "Allow delete on availability_blocks" ON public.availability_blocks FOR DELETE USING (true);

-- 6. SHIFT REQUESTS
CREATE TABLE IF NOT EXISTS public.shift_requests (
  id text PRIMARY KEY,
  detailer_id text NOT NULL,
  team_member_id text NOT NULL,
  team_member_name text NOT NULL,
  team_member_role text,
  requested_schedule jsonb DEFAULT '[]'::jsonb,
  specific_date_off timestamp with time zone,
  reason text DEFAULT '',
  status text DEFAULT 'pending',
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  reviewed_at timestamp with time zone,
  reviewer_notes text
);

ALTER TABLE public.shift_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on shift_requests" ON public.shift_requests;
DROP POLICY IF EXISTS "Allow insert on shift_requests" ON public.shift_requests;
DROP POLICY IF EXISTS "Allow update on shift_requests" ON public.shift_requests;
DROP POLICY IF EXISTS "Allow delete on shift_requests" ON public.shift_requests;
CREATE POLICY "Allow read on shift_requests" ON public.shift_requests FOR SELECT USING (true);
CREATE POLICY "Allow insert on shift_requests" ON public.shift_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on shift_requests" ON public.shift_requests FOR UPDATE USING (true);
CREATE POLICY "Allow delete on shift_requests" ON public.shift_requests FOR DELETE USING (true);

-- 7. REALTIME PUBLICATIONS
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.team_members; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_items; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.availability_blocks; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.shift_requests; EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 8. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
