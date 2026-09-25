-- =======================================================
-- AutoDetailCraft Complete Database Schema & Multi-Device Sync Repair
-- Copy and run this script in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Run
-- =======================================================

-- 1. PROFILES TABLE
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text default 'Vehicle Owner',
  business_name text default 'My Detailing Studio',
  role text default 'client', -- 'client' or 'detailer'
  avatar_url text default 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
  cover_url text default 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
  location text default 'Austin, Texas',
  service_radius text default '25 miles • Mobile & Studio',
  bio text default 'Car enthusiast & detailing craft connoisseur.',
  phone text default '',
  instagram_handle text default '@detailcraft',
  is_verified_host boolean default false,
  is_ida_certified boolean default false,
  rating numeric default 5.0,
  review_count integer default 0,
  total_jobs_count integer default 0,
  starting_price numeric default 150.0,
  subscription_tier text default 'free',
  service_packages jsonb default '[]'::jsonb,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;

drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Users can update their own profile." on public.profiles;
drop policy if exists "Allow read on profiles" on public.profiles;
drop policy if exists "Allow insert on profiles" on public.profiles;
drop policy if exists "Allow update on profiles" on public.profiles;

create policy "Allow read on profiles" on public.profiles for select using (true);
create policy "Allow insert on profiles" on public.profiles for insert with check (true);
create policy "Allow update on profiles" on public.profiles for update using (true);

-- 2. VEHICLES TABLE (User Garage)
create table if not exists public.vehicles (
  id text primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  year integer not null,
  make text not null,
  model text not null,
  trim text default '',
  paint_color text default '',
  paint_type text default 'Clearcoat',
  image_url text default '',
  license_plate text default '',
  notes text default '',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.vehicles enable row level security;

drop policy if exists "Anyone can view vehicles for discovery/bookings." on public.vehicles;
drop policy if exists "Users can insert their own vehicles." on public.vehicles;
drop policy if exists "Users can update their own vehicles." on public.vehicles;
drop policy if exists "Users can delete their own vehicles." on public.vehicles;
drop policy if exists "Allow read on vehicles" on public.vehicles;
drop policy if exists "Allow insert on vehicles" on public.vehicles;
drop policy if exists "Allow update on vehicles" on public.vehicles;
drop policy if exists "Allow delete on vehicles" on public.vehicles;

create policy "Allow read on vehicles" on public.vehicles for select using (true);
create policy "Allow insert on vehicles" on public.vehicles for insert with check (true);
create policy "Allow update on vehicles" on public.vehicles for update using (true);
create policy "Allow delete on vehicles" on public.vehicles for delete using (true);

-- 3. TEAM MEMBERS TABLE (Hired Staff)
create table if not exists public.team_members (
  id text primary key,
  studio_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  role_title text not null,
  avatar_url text default '',
  rating numeric default 5.0,
  completed_jobs_count integer default 0,
  is_available boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.team_members enable row level security;

drop policy if exists "Team members are viewable by everyone." on public.team_members;
drop policy if exists "Studios can manage their team members." on public.team_members;
drop policy if exists "Allow read on team_members" on public.team_members;
drop policy if exists "Allow insert on team_members" on public.team_members;
drop policy if exists "Allow update on team_members" on public.team_members;
drop policy if exists "Allow delete on team_members" on public.team_members;

create policy "Allow read on team_members" on public.team_members for select using (true);
create policy "Allow insert on team_members" on public.team_members for insert with check (true);
create policy "Allow update on team_members" on public.team_members for update using (true);
create policy "Allow delete on team_members" on public.team_members for delete using (true);

-- 4. JOBS TABLE (Transformations / Recipes)
create table if not exists public.jobs (
  id text primary key,
  author_id text not null,
  title text not null,
  description text default '',
  vehicle_year integer,
  vehicle_make text,
  vehicle_model text,
  paint_color text,
  service_type text,
  before_image_url text,
  after_image_url text,
  raw_data jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.jobs enable row level security;

drop policy if exists "Allow read on jobs" on public.jobs;
drop policy if exists "Allow insert on jobs" on public.jobs;
drop policy if exists "Allow update on jobs" on public.jobs;
drop policy if exists "Allow delete on jobs" on public.jobs;

create policy "Allow read on jobs" on public.jobs for select using (true);
create policy "Allow insert on jobs" on public.jobs for insert with check (true);
create policy "Allow update on jobs" on public.jobs for update using (true);
create policy "Allow delete on jobs" on public.jobs for delete using (true);

-- 5. BOOKINGS TABLE (Appointments)
create table if not exists public.bookings (
  id text primary key,
  client_id text,
  detailer_id text not null,
  detailer_name text not null,
  detailer_business_name text not null,
  detailer_avatar text default '',
  client_name text not null,
  client_phone text default '',
  client_email text default '',
  vehicle_year_make_model text not null,
  vehicle_size text not null,
  package jsonb not null,
  location_type text not null,
  client_address text default '',
  scheduled_date timestamp with time zone not null,
  scheduled_time_slot text not null,
  total_price numeric not null,
  deposit_amount numeric not null,
  status text not null default 'confirmed',
  client_notes text,
  pre_inspection_summary text,
  warranty_passport_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.bookings enable row level security;

drop policy if exists "Allow read on bookings" on public.bookings;
drop policy if exists "Allow insert on bookings" on public.bookings;
drop policy if exists "Allow update on bookings" on public.bookings;
drop policy if exists "Allow delete on bookings" on public.bookings;

create policy "Allow read on bookings" on public.bookings for select using (true);
create policy "Allow insert on bookings" on public.bookings for insert with check (true);
create policy "Allow update on bookings" on public.bookings for update using (true);
create policy "Allow delete on bookings" on public.bookings for delete using (true);

-- 6. USER INTERACTIONS TABLE (Likes & Saves sync)
create table if not exists public.user_interactions (
  user_id text primary key,
  liked_job_ids jsonb default '[]'::jsonb,
  saved_job_ids jsonb default '[]'::jsonb,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.user_interactions enable row level security;

drop policy if exists "Allow read on user_interactions" on public.user_interactions;
drop policy if exists "Allow insert on user_interactions" on public.user_interactions;
drop policy if exists "Allow update on user_interactions" on public.user_interactions;

create policy "Allow read on user_interactions" on public.user_interactions for select using (true);
create policy "Allow insert on user_interactions" on public.user_interactions for insert with check (true);
create policy "Allow update on user_interactions" on public.user_interactions for update using (true);

-- 7. CONVERSATIONS TABLE
create table if not exists public.conversations (
  id text primary key default gen_random_uuid()::text,
  participant_a text not null,
  participant_b text not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.conversations enable row level security;

drop policy if exists "Allow read on conversations" on public.conversations;
drop policy if exists "Allow insert on conversations" on public.conversations;
drop policy if exists "Allow update on conversations" on public.conversations;

create policy "Allow read on conversations" on public.conversations for select using (true);
create policy "Allow insert on conversations" on public.conversations for insert with check (true);
create policy "Allow update on conversations" on public.conversations for update using (true);

-- 8. MESSAGES TABLE
create table if not exists public.messages (
  id text primary key default gen_random_uuid()::text,
  conversation_id text references public.conversations(id) on delete cascade not null,
  sender_id text not null,
  text text not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.messages enable row level security;

drop policy if exists "Allow read on messages" on public.messages;
drop policy if exists "Allow insert on messages" on public.messages;
drop policy if exists "Allow update on messages" on public.messages;

create policy "Allow read on messages" on public.messages for select using (true);
create policy "Allow insert on messages" on public.messages for insert with check (true);
create policy "Allow update on messages" on public.messages for update using (true);

-- 9. Enable Realtime Publications for seamless multi-device live sync
do $$
begin
  alter publication supabase_realtime add table public.jobs;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.bookings;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.user_interactions;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception when others then null;
end $$;

-- 10. Notify PostgREST to reload its schema cache immediately
notify pgrst, 'reload schema';
