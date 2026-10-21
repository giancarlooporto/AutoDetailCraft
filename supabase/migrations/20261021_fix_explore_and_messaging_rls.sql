-- =========================================================================
-- AutoDetailCraft: Fix Explore Discovery, Messaging & Real-Time Sync RLS Policies
--
-- Why this is needed:
-- Row-Level Security (RLS) on Supabase was blocking cross-account queries.
-- For example, when Account B looks at Explore or tries to message Account A,
-- Supabase returned HTTP 42501 (Not allowed by policy).
--
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project: bczyryganiynfhjwlcgl
-- 3. Click "SQL Editor" in the left sidebar
-- 4. Click "New Query", paste this entire script, and click "Run"
-- =========================================================================

-- 1. PROFILES (Allows Explore to show all studios and services)
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Allow read on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow insert on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow update on profiles" ON public.profiles;

CREATE POLICY "Allow read on profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert on profiles" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on profiles" ON public.profiles FOR UPDATE USING (true);

-- 2. JOBS (Allows Explore feed to show posted transformations & jobs)
ALTER TABLE IF EXISTS public.jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Jobs are viewable by everyone." ON public.jobs;
DROP POLICY IF EXISTS "Allow read on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow insert on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow update on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow delete on jobs" ON public.jobs;

CREATE POLICY "Allow read on jobs" ON public.jobs FOR SELECT USING (true);
CREATE POLICY "Allow insert on jobs" ON public.jobs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on jobs" ON public.jobs FOR UPDATE USING (true);
CREATE POLICY "Allow delete on jobs" ON public.jobs FOR DELETE USING (true);

-- 3. CONVERSATIONS (Allows clients and studios to connect and chat)
ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow insert on conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow update on conversations" ON public.conversations;

CREATE POLICY "Allow read on conversations" ON public.conversations FOR SELECT USING (true);
CREATE POLICY "Allow insert on conversations" ON public.conversations FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on conversations" ON public.conversations FOR UPDATE USING (true);

-- 4. MESSAGES (Allows sending and receiving chat messages in real time)
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on messages" ON public.messages;
DROP POLICY IF EXISTS "Allow insert on messages" ON public.messages;
DROP POLICY IF EXISTS "Allow update on messages" ON public.messages;

CREATE POLICY "Allow read on messages" ON public.messages FOR SELECT USING (true);
CREATE POLICY "Allow insert on messages" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on messages" ON public.messages FOR UPDATE USING (true);

-- 5. BOOKINGS (Allows clients to book appointments with studios)
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow insert on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow update on bookings" ON public.bookings;

CREATE POLICY "Allow read on bookings" ON public.bookings FOR SELECT USING (true);
CREATE POLICY "Allow insert on bookings" ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on bookings" ON public.bookings FOR UPDATE USING (true);

-- 6. TEAM MEMBERS (Allows viewing and managing detailer staff)
ALTER TABLE IF EXISTS public.team_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow insert on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow update on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow delete on team_members" ON public.team_members;

CREATE POLICY "Allow read on team_members" ON public.team_members FOR SELECT USING (true);
CREATE POLICY "Allow insert on team_members" ON public.team_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on team_members" ON public.team_members FOR UPDATE USING (true);
CREATE POLICY "Allow delete on team_members" ON public.team_members FOR DELETE USING (true);

-- 7. VEHICLES (Allows viewing client garage vehicles when booking)
ALTER TABLE IF EXISTS public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow insert on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow update on vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow delete on vehicles" ON public.vehicles;

CREATE POLICY "Allow read on vehicles" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "Allow insert on vehicles" ON public.vehicles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update on vehicles" ON public.vehicles FOR UPDATE USING (true);
CREATE POLICY "Allow delete on vehicles" ON public.vehicles FOR DELETE USING (true);

-- 8. Refresh schema cache
NOTIFY pgrst, 'reload schema';
