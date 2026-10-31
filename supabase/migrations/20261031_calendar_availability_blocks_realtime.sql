-- =========================================================================
-- AutoDetailCraft: Calendar Availability Blocks & Preferences Realtime Sync
-- Migration: 20261031_calendar_availability_blocks_realtime.sql
--
-- Why this is needed:
-- 1. Creates public.availability_blocks table for multi-device sync of 
--    manual 30-minute blocked slots, full-day blocks, and technician schedules.
-- 2. Adds calendar_preferences column to public.profiles for operating hours sync.
-- 3. Enables REPLICA IDENTITY FULL for complete payload delivery on real-time deletes.
-- 4. Registers public.availability_blocks in supabase_realtime publication.
-- 5. Configures permissive Row Level Security (RLS) policies so clients can read
--    studio availability during booking, and detailers can manage blocks across devices.
-- 6. Reloads PostgREST schema cache.
--
-- How to apply:
-- 1. Open Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project
-- 3. Open "SQL Editor"
-- 4. Paste and Run this script
-- =========================================================================

-- 1. ADD CALENDAR_PREFERENCES TO PROFILES IF MISSING
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS calendar_preferences jsonb DEFAULT '{}'::jsonb;

-- 2. CREATE AVAILABILITY BLOCKS TABLE
CREATE TABLE IF NOT EXISTS public.availability_blocks (
  id text PRIMARY KEY,
  detailer_id text NOT NULL,
  team_member_id text,
  date timestamp with time zone NOT NULL,
  is_all_day boolean DEFAULT false,
  blocked_slots jsonb DEFAULT '[]'::jsonb,
  custom_slots jsonb DEFAULT '[]'::jsonb,
  has_custom_slots_override boolean DEFAULT false,
  reason text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for fast queries by detailer_id and date
CREATE INDEX IF NOT EXISTS idx_availability_blocks_detailer_date
  ON public.availability_blocks (detailer_id, date);

-- 3. REPLICA IDENTITY FULL FOR REALTIME DELETE PAYLOADS
ALTER TABLE IF EXISTS public.availability_blocks REPLICA IDENTITY FULL;

-- 4. REALTIME PUBLICATION REGISTRATION
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.availability_blocks;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 5. ROW LEVEL SECURITY POLICIES
ALTER TABLE IF EXISTS public.availability_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow insert on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow update on availability_blocks" ON public.availability_blocks;
DROP POLICY IF EXISTS "Allow delete on availability_blocks" ON public.availability_blocks;

CREATE POLICY "Allow read on availability_blocks"
  ON public.availability_blocks FOR SELECT
  USING (true);

CREATE POLICY "Allow insert on availability_blocks"
  ON public.availability_blocks FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow update on availability_blocks"
  ON public.availability_blocks FOR UPDATE
  USING (true);

CREATE POLICY "Allow delete on availability_blocks"
  ON public.availability_blocks FOR DELETE
  USING (true);

-- 6. RELOAD SCHEMA CACHE FOR POSTGREST
NOTIFY pgrst, 'reload schema';
