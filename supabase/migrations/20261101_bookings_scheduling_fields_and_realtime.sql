-- =========================================================================
-- AutoDetailCraft: Bookings Scheduling Fields & Multi-Device Realtime Sync
-- Migration: 20261101_bookings_scheduling_fields_and_realtime.sql
--
-- Why this is needed:
-- 1. Adds missing scheduling fields to public.bookings:
--    - start_time text (arrival / drop-off window start)
--    - end_time text (ready / pick-up time)
--    - completion_date timestamp with time zone (supports next-day & multi-day rollovers)
--    - duration_minutes integer (precise package duration in minutes)
--    - is_multi_day boolean default false
-- 2. Ensures REPLICA IDENTITY FULL for complete payload delivery on real-time deletes & updates.
-- 3. Ensures public.bookings is registered in supabase_realtime publication.
-- 4. Reloads PostgREST schema cache.
-- =========================================================================

-- 1. ADD SCHEDULING FIELDS TO BOOKINGS
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS start_time text,
  ADD COLUMN IF NOT EXISTS end_time text,
  ADD COLUMN IF NOT EXISTS completion_date timestamp with time zone,
  ADD COLUMN IF NOT EXISTS duration_minutes integer,
  ADD COLUMN IF NOT EXISTS is_multi_day boolean DEFAULT false;

-- Index for queries by detailer_id and scheduled_date
CREATE INDEX IF NOT EXISTS idx_bookings_detailer_date
  ON public.bookings (detailer_id, scheduled_date);

-- 2. REPLICA IDENTITY FULL FOR REALTIME PAYLOADS
ALTER TABLE IF EXISTS public.bookings REPLICA IDENTITY FULL;

-- 3. ENSURE REALTIME PUBLICATION REGISTRATION
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. RELOAD SCHEMA CACHE FOR POSTGREST
NOTIFY pgrst, 'reload schema';
