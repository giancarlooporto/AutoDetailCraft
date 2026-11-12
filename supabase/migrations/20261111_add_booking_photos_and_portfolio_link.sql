-- =========================================================================
-- AutoDetailCraft: Booking Inspection Photos (Cloudflare R2) & Portfolio Link
-- Migration: 20261111_add_booking_photos_and_portfolio_link.sql
--
-- Why this is needed:
-- 1. Extends public.bookings with lightweight Cloudflare R2 CDN URL arrays
--    (before_photos, after_photos), completion_notes, and portfolio_job_id.
-- 2. Binary image files are uploaded exclusively to Cloudflare R2
--    (https://media.autodetailcraft.com/...), so Supabase PostgreSQL only
--    stores lightweight URL strings and never fills up with photo binaries.
-- =========================================================================

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS before_photos text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS after_photos text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS completion_notes text,
  ADD COLUMN IF NOT EXISTS portfolio_job_id text;

CREATE INDEX IF NOT EXISTS idx_bookings_portfolio_job_id
  ON public.bookings (portfolio_job_id);

ALTER TABLE IF EXISTS public.bookings REPLICA IDENTITY FULL;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';
