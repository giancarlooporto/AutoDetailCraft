-- =======================================================
-- AutoDetailCraft Database Schema
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor)
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
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table public.profiles enable row level security;

-- Profiles Policies
create policy "Public profiles are viewable by everyone."
  on public.profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on public.profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update their own profile."
  on public.profiles for update
  using ( auth.uid() = id );

-- 2. VEHICLES TABLE (User's Garage)
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

create policy "Anyone can view vehicles for discovery/bookings."
  on public.vehicles for select
  using ( true );

create policy "Users can insert their own vehicles."
  on public.vehicles for insert
  with check ( auth.uid() = user_id );

create policy "Users can update their own vehicles."
  on public.vehicles for update
  using ( auth.uid() = user_id );

create policy "Users can delete their own vehicles."
  on public.vehicles for delete
  using ( auth.uid() = user_id );

-- 3. TEAM MEMBERS TABLE (Hired Staff under studio)
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

create policy "Team members are viewable by everyone."
  on public.team_members for select
  using ( true );

create policy "Studios can manage their team members."
  on public.team_members for all
  using ( auth.uid() = studio_id );

-- 4. STORAGE POLICY FOR VEHICLE-PHOTOS BUCKET
-- Run this so photo uploads never get blocked by 403 Forbidden!
insert into storage.buckets (id, name, public)
values ('vehicle-photos', 'vehicle-photos', true)
on conflict (id) do update set public = true;

create policy "Public Access to vehicle-photos"
  on storage.objects for select
  using ( bucket_id = 'vehicle-photos' );

create policy "Authenticated users can upload photos"
  on storage.objects for insert
  with check ( bucket_id = 'vehicle-photos' and auth.role() = 'authenticated' );

create policy "Users can update their uploaded photos"
  on storage.objects for update
  using ( bucket_id = 'vehicle-photos' and auth.role() = 'authenticated' );

create policy "Users can delete their uploaded photos"
  on storage.objects for delete
  using ( bucket_id = 'vehicle-photos' and auth.role() = 'authenticated' );
