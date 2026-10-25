-- Migration: Permanent Account Deletion
-- Enables users to permanently delete their account and all associated data.

-- 1. Add DELETE policy on public.profiles so users can delete their own profile
drop policy if exists "Users can delete their own profile." on public.profiles;
create policy "Users can delete their own profile."
  on public.profiles for delete
  using ( auth.uid() = id );

-- 2. Add DELETE policy on public.vehicles if not already present
drop policy if exists "Users can delete their own vehicles." on public.vehicles;
create policy "Users can delete their own vehicles."
  on public.vehicles for delete
  using ( auth.uid() = user_id );

-- 3. Add DELETE policy on public.team_members
drop policy if exists "Studios can delete their own team members." on public.team_members;
create policy "Studios can delete their own team members."
  on public.team_members for delete
  using ( auth.uid() = studio_id );

-- 4. Add DELETE policy on public.inventory_items if exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'inventory_items') then
    drop policy if exists "Users can delete their own inventory items." on public.inventory_items;
    create policy "Users can delete their own inventory items."
      on public.inventory_items for delete
      using ( auth.uid() = user_id );
  end if;
end $$;

-- 5. Add DELETE policy on public.availability_blocks if exists
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'availability_blocks') then
    drop policy if exists "Users can delete their own availability blocks." on public.availability_blocks;
    create policy "Users can delete their own availability blocks."
      on public.availability_blocks for delete
      using ( auth.uid() = detailer_id or auth.uid() = user_id );
  end if;
end $$;

-- 6. RPC Function with SECURITY DEFINER to completely purge user from auth.users and all tables
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Delete user vehicles
  delete from public.vehicles where user_id = v_user_id;

  -- 2. Delete bookings (as client or as studio host, matching user id or email)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'bookings') then
    delete from public.bookings
      where client_id = v_user_id::text
         or detailer_id = v_user_id::text
         or client_email = (select email from auth.users where id = v_user_id);
  end if;

  -- 3. Delete team members owned by this studio
  delete from public.team_members where studio_id = v_user_id;

  -- 4. Delete shift requests
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shift_requests') then
    delete from public.shift_requests where detailer_id = v_user_id::text;
  end if;

  -- 5. Delete chat messages and conversations
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'messages') then
    delete from public.messages where sender_id = v_user_id::text;
  end if;
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'conversations') then
    delete from public.conversations where participant_a = v_user_id::text or participant_b = v_user_id::text;
  end if;

  -- 6. Delete inventory items (if table exists)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'inventory_items') then
    delete from public.inventory_items where user_id = v_user_id;
  end if;

  -- 7. Delete availability blocks (if table exists)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'availability_blocks') then
    delete from public.availability_blocks where user_id = v_user_id or detailer_id = v_user_id;
  end if;

  -- 8. Delete user interactions (if table exists)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'user_interactions') then
    delete from public.user_interactions where user_id = v_user_id;
  end if;

  -- 9. Delete published jobs
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'jobs') then
    delete from public.jobs where author_id = v_user_id;
  end if;

  -- 10. Delete verification requests (if table exists)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'verification_requests') then
    delete from public.verification_requests where user_id = v_user_id::text;
  end if;

  -- 11. Delete owner PINs (if table exists)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'owner_pins') then
    delete from public.owner_pins where user_id = v_user_id;
  end if;

  -- 12. Delete public profile (also removes custom service_packages, bio, credentials)
  delete from public.profiles where id = v_user_id;

  -- 13. Delete authentication record from Supabase Auth
  delete from auth.users where id = v_user_id;
end;
$$;

-- Grant execution permission to authenticated users
grant execute on function public.delete_user_account() to authenticated;
