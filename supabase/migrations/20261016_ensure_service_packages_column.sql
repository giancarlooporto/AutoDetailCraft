-- =========================================================================
-- AutoDetailCraft: Ensure service_packages Column & RLS Policies in Supabase
--
-- If custom service packages disappear after browser refresh, run this script
-- in your Supabase Dashboard:
-- 1. Open your project at https://supabase.com/dashboard
-- 2. Click "SQL Editor" in the left sidebar
-- 3. Click "New Query", paste this entire script, and click "Run"
-- =========================================================================

-- 1. Add service_packages column to profiles table if missing
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS service_packages jsonb DEFAULT '[]'::jsonb;

-- 2. Ensure Row Level Security (RLS) is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Recreate policies to ensure profiles can be read and updated
DROP POLICY IF EXISTS "Allow read on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow insert on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow update on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles;

-- Open policies suitable for multi-device sync
CREATE POLICY "Allow read on profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert on profiles" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on profiles" ON public.profiles FOR UPDATE USING (true);

-- 4. Reload the PostgREST schema cache so the new column is immediately recognized
NOTIFY pgrst, 'reload schema';
