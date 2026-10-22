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

-- 8. PROFILES & BOOKINGS COLUMNS & REALTIME
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_insurance_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS insurance_policy_number text DEFAULT '',
  ADD COLUMN IF NOT EXISTS insurance_expiry_date date;

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS detailer_name text,
  ADD COLUMN IF NOT EXISTS detailer_business_name text,
  ADD COLUMN IF NOT EXISTS detailer_avatar text DEFAULT '',
  ADD COLUMN IF NOT EXISTS assigned_team_member_id text,
  ADD COLUMN IF NOT EXISTS assigned_team_member_name text,
  ADD COLUMN IF NOT EXISTS package jsonb,
  ADD COLUMN IF NOT EXISTS package_data jsonb,
  ADD COLUMN IF NOT EXISTS location_type text,
  ADD COLUMN IF NOT EXISTS service_location_type text;

ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.bookings REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 9. CLAIM GUEST BOOKINGS RPC FUNCTION
-- Allows authenticated users to automatically claim any past bookings created as a guest with their email
CREATE OR REPLACE FUNCTION public.claim_guest_bookings(target_email text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  claimed_count integer;
  current_uid uuid;
BEGIN
  current_uid := auth.uid();
  IF current_uid IS NULL OR target_email IS NULL OR trim(target_email) = '' THEN
    RETURN 0;
  END IF;

  UPDATE public.bookings
  SET client_id = current_uid,
      updated_at = timezone('utc'::text, now())
  WHERE lower(trim(client_email)) = lower(trim(target_email))
    AND (client_id IS NULL OR client_id = current_uid);

  GET DIAGNOSTICS claimed_count = ROW_COUNT;
  RETURN claimed_count;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_guest_bookings(text) FROM public;
GRANT EXECUTE ON FUNCTION public.claim_guest_bookings(text) TO authenticated, anon;

-- 10. AUTO-CONFIRM USERS (Ensures test & client accounts can sign in immediately without email link confirmation)
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
    confirmed_at = COALESCE(confirmed_at, now())
WHERE email_confirmed_at IS NULL;

CREATE OR REPLACE FUNCTION public.auto_confirm_new_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NEW.email_confirmed_at := COALESCE(NEW.email_confirmed_at, now());
  NEW.confirmed_at := COALESCE(NEW.confirmed_at, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;
CREATE TRIGGER on_auth_user_created_auto_confirm
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_new_users();

-- 11. Refresh schema cache
NOTIFY pgrst, 'reload schema';

