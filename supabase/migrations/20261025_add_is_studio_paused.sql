-- ==============================================================================
-- AutoDetailCraft: Studio Vacation / Pause Operations Mode
-- Adds `is_studio_paused` column to profiles table.
-- When true, hides the studio from public discovery and search while preserving
-- all services, pricing, inventory, and staff configurations.
-- ==============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_studio_paused BOOLEAN DEFAULT FALSE;

-- Ensure public view/query indexing for active unpaused studios
CREATE INDEX IF NOT EXISTS idx_profiles_studio_paused
ON public.profiles (is_studio_paused)
WHERE role = 'detailer' OR role = 'super_admin';

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
