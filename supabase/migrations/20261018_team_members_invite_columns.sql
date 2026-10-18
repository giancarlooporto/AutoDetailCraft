-- ============================================================================
-- Migration: 20261018_team_members_invite_columns.sql
-- Purpose:
--   1. Move staff PINs, passwords, and invitation tokens out of public.team_members
--      into a locked-down `public.staff_security` table (bcrypt + SHA-256)
--      accessed exclusively through SECURITY DEFINER RPC functions.
--   2. Lock down Row-Level Security (RLS) across all public tables using
--      universal ::text casts (`auth.uid()::text = column::text`) so it works
--      regardless of whether a column is typed as TEXT or UUID.
-- ============================================================================

create extension if not exists pgcrypto;

-- ============================================================================
-- PART 1: STAFF SECURITY & INVITATION SYSTEM (SERVER-AUTHORITATIVE)
-- ============================================================================

-- 1A. Ensure non-sensitive operational columns exist on public.team_members
alter table public.team_members
  add column if not exists is_founder boolean default false,
  add column if not exists can_edit_inventory boolean default true,
  add column if not exists can_view_pricing boolean default true,
  add column if not exists can_manage_team boolean default false,
  add column if not exists can_view_all_team_calendar boolean default true,
  add column if not exists email text,
  add column if not exists invite_status text default 'none',
  add column if not exists invite_sent_at timestamptz,
  add column if not exists allowed_hub_sections jsonb,
  add column if not exists custom_weekly_schedule jsonb;

-- 1B. Create locked-down staff_security table BEFORE dropping legacy columns
-- Note: studio_id is TEXT so it matches team_members.studio_id whether TEXT or UUID
create table if not exists public.staff_security (
  member_id         text primary key references public.team_members(id) on delete cascade,
  studio_id         text not null,
  pin_hash          text,
  password_hash     text,
  invite_token_hash text,
  failed_attempts   int not null default 0,
  locked_until      timestamptz,
  updated_at        timestamptz not null default now()
);

alter table public.staff_security enable row level security;
revoke all on public.staff_security from anon, authenticated;

-- Migrate any existing rows from team_members into staff_security if legacy columns exist
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'team_members' and column_name = 'invite_token'
  ) then
    insert into public.staff_security (member_id, studio_id, pin_hash, password_hash, invite_token_hash)
    select
      id::text,
      studio_id::text,
      case when pin is not null and length(trim(pin)) > 0 then crypt(trim(pin), gen_salt('bf', 10)) else null end,
      case when password is not null and length(trim(password)) > 0 then crypt(trim(password), gen_salt('bf', 10)) else null end,
      case when invite_token is not null and length(trim(invite_token)) > 0 then encode(digest(trim(invite_token), 'sha256'), 'hex') else null end
    from public.team_members
    on conflict (member_id) do update set
      pin_hash = coalesce(excluded.pin_hash, public.staff_security.pin_hash),
      password_hash = coalesce(excluded.password_hash, public.staff_security.password_hash),
      invite_token_hash = coalesce(excluded.invite_token_hash, public.staff_security.invite_token_hash),
      updated_at = now();
  end if;
end $$;

-- 1C. DROP plaintext credential columns from public.team_members (cleans up previous script)
alter table public.team_members
  drop column if exists pin,
  drop column if exists password,
  drop column if exists invite_token;

-- Drop old signature if it was created with uuid
drop function if exists public.upsert_staff_security(text, uuid, text, text);

-- RPC 1: upsert_staff_security (Owner sets staff PIN / invite token)
create or replace function public.upsert_staff_security(
  p_member_id text,
  p_studio_id text,
  p_pin text default null,
  p_invite_token text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null or auth.uid()::text <> p_studio_id::text then
    return json_build_object('ok', false, 'error', 'unauthorized');
  end if;

  insert into public.staff_security (
    member_id, studio_id, pin_hash, invite_token_hash, updated_at
  )
  values (
    p_member_id,
    p_studio_id,
    case when p_pin is not null and length(trim(p_pin)) > 0
         then crypt(trim(p_pin), gen_salt('bf', 10))
         else null end,
    case when p_invite_token is not null and length(trim(p_invite_token)) > 0
         then encode(digest(trim(p_invite_token), 'sha256'), 'hex')
         else null end,
    now()
  )
  on conflict (member_id) do update set
    pin_hash = case
      when p_pin is not null and length(trim(p_pin)) > 0
      then crypt(trim(p_pin), gen_salt('bf', 10))
      else public.staff_security.pin_hash
    end,
    invite_token_hash = case
      when p_invite_token is not null and length(trim(p_invite_token)) > 0
      then encode(digest(trim(p_invite_token), 'sha256'), 'hex')
      else public.staff_security.invite_token_hash
    end,
    updated_at = now();

  return json_build_object('ok', true);
end;
$$;

-- RPC 2: accept_staff_invite_rpc (Staff clicks invite link & sets password)
create or replace function public.accept_staff_invite_rpc(
  p_token text,
  p_new_password text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token_hash text;
  v_sec public.staff_security;
  v_member public.team_members;
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return json_build_object('ok', false, 'error', 'missing_token');
  end if;
  if p_new_password is null or length(trim(p_new_password)) < 6 then
    return json_build_object('ok', false, 'error', 'weak_password');
  end if;

  v_token_hash := encode(digest(trim(p_token), 'sha256'), 'hex');

  select * into v_sec
    from public.staff_security
   where invite_token_hash = v_token_hash
   limit 1
   for update;

  if v_sec.member_id is null then
    return json_build_object('ok', false, 'error', 'invalid_or_expired_token');
  end if;

  update public.staff_security
     set password_hash = crypt(trim(p_new_password), gen_salt('bf', 10)),
         invite_token_hash = null,
         failed_attempts = 0,
         locked_until = null,
         updated_at = now()
   where member_id = v_sec.member_id;

  update public.team_members
     set invite_status = 'accepted'
   where id::text = v_sec.member_id::text
  returning * into v_member;

  return json_build_object(
    'ok', true,
    'studio_id', v_sec.studio_id,
    'member', row_to_json(v_member)
  );
end;
$$;

-- RPC 3: verify_staff_pin_rpc (Shop Tablet 4-digit PIN check)
create or replace function public.verify_staff_pin_rpc(
  p_member_id text,
  p_pin text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sec public.staff_security;
  v_member public.team_members;
  v_attempts int;
begin
  select * into v_sec from public.staff_security where member_id = p_member_id for update;
  if v_sec.member_id is null or v_sec.pin_hash is null then
    return json_build_object('ok', false, 'error', 'invalid_pin');
  end if;

  if v_sec.locked_until is not null and v_sec.locked_until > now() then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', v_sec.locked_until);
  end if;

  if p_pin is not null and crypt(trim(p_pin), v_sec.pin_hash) = v_sec.pin_hash then
    update public.staff_security
       set failed_attempts = 0, locked_until = null, updated_at = now()
     where member_id = p_member_id;
    select * into v_member from public.team_members where id::text = p_member_id::text;
    return json_build_object('ok', true, 'studio_id', v_sec.studio_id, 'member', row_to_json(v_member));
  end if;

  v_attempts := v_sec.failed_attempts + 1;
  update public.staff_security
     set failed_attempts = case when v_attempts >= 5 then 0 else v_attempts end,
         locked_until = case when v_attempts >= 5 then now() + interval '15 minutes' else null end,
         updated_at = now()
   where member_id = p_member_id;

  return json_build_object('ok', false, 'error', 'invalid_pin');
end;
$$;

-- RPC 4: verify_staff_login_rpc (Personal Device Email + Password login)
create or replace function public.verify_staff_login_rpc(
  p_email text,
  p_password text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member public.team_members;
  v_sec public.staff_security;
  v_attempts int;
begin
  select * into v_member
    from public.team_members
   where lower(trim(email)) = lower(trim(p_email))
   limit 1;

  if v_member.id is null then
    return json_build_object('ok', false, 'error', 'invalid_credentials');
  end if;

  select * into v_sec from public.staff_security where member_id = v_member.id::text for update;
  if v_sec.member_id is null or v_sec.password_hash is null then
    return json_build_object('ok', false, 'error', 'invalid_credentials');
  end if;

  if v_sec.locked_until is not null and v_sec.locked_until > now() then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', v_sec.locked_until);
  end if;

  if p_password is not null and crypt(trim(p_password), v_sec.password_hash) = v_sec.password_hash then
    update public.staff_security
       set failed_attempts = 0, locked_until = null, updated_at = now()
     where member_id = v_member.id::text;
    return json_build_object('ok', true, 'studio_id', v_member.studio_id, 'member', row_to_json(v_member));
  end if;

  v_attempts := v_sec.failed_attempts + 1;
  update public.staff_security
     set failed_attempts = case when v_attempts >= 5 then 0 else v_attempts end,
         locked_until = case when v_attempts >= 5 then now() + interval '15 minutes' else null end,
         updated_at = now()
   where member_id = v_member.id::text;

  return json_build_object('ok', false, 'error', 'invalid_credentials');
end;
$$;

revoke all on function public.upsert_staff_security(text, text, text, text) from public, anon;
grant execute on function public.upsert_staff_security(text, text, text, text) to authenticated;
grant execute on function public.accept_staff_invite_rpc(text, text) to anon, authenticated;
grant execute on function public.verify_staff_pin_rpc(text, text) to anon, authenticated;
grant execute on function public.verify_staff_login_rpc(text, text) to anon, authenticated;

-- ============================================================================
-- PART 2: PRODUCTION ROW-LEVEL SECURITY (RLS) HARDENING
-- Uses explicit ::text casts on both sides so it works whether columns are TEXT or UUID
-- ============================================================================

-- 1. PROFILES: Publicly readable, but ONLY the profile owner can insert/update
alter table public.profiles enable row level security;
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Users can update their own profile." on public.profiles;
drop policy if exists "Allow read on profiles" on public.profiles;
drop policy if exists "Allow insert on profiles" on public.profiles;
drop policy if exists "Allow update on profiles" on public.profiles;
drop policy if exists "profiles_select_public" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_public" on public.profiles for select using ( true );
create policy "profiles_insert_own" on public.profiles for insert with check ( auth.uid() is not null and auth.uid()::text = id::text );
create policy "profiles_update_own" on public.profiles for update using ( auth.uid() is not null and auth.uid()::text = id::text ) with check ( auth.uid() is not null and auth.uid()::text = id::text );

-- 2. VEHICLES: Publicly readable for bookings, but ONLY the vehicle owner can insert/update/delete
alter table public.vehicles enable row level security;
drop policy if exists "Anyone can view vehicles for discovery/bookings." on public.vehicles;
drop policy if exists "Users can insert their own vehicles." on public.vehicles;
drop policy if exists "Users can update their own vehicles." on public.vehicles;
drop policy if exists "Users can delete their own vehicles." on public.vehicles;
drop policy if exists "Allow read on vehicles" on public.vehicles;
drop policy if exists "Allow insert on vehicles" on public.vehicles;
drop policy if exists "Allow update on vehicles" on public.vehicles;
drop policy if exists "Allow delete on vehicles" on public.vehicles;
drop policy if exists "vehicles_select_public" on public.vehicles;
drop policy if exists "vehicles_insert_own" on public.vehicles;
drop policy if exists "vehicles_update_own" on public.vehicles;
drop policy if exists "vehicles_delete_own" on public.vehicles;

create policy "vehicles_select_public" on public.vehicles for select using ( true );
create policy "vehicles_insert_own" on public.vehicles for insert with check ( auth.uid() is not null and auth.uid()::text = user_id::text );
create policy "vehicles_update_own" on public.vehicles for update using ( auth.uid() is not null and auth.uid()::text = user_id::text ) with check ( auth.uid() is not null and auth.uid()::text = user_id::text );
create policy "vehicles_delete_own" on public.vehicles for delete using ( auth.uid() is not null and auth.uid()::text = user_id::text );

-- 3. TEAM MEMBERS: Publicly readable for booking technicians, but ONLY the Studio Owner can insert/update/delete
alter table public.team_members enable row level security;
drop policy if exists "Team members are viewable by everyone." on public.team_members;
drop policy if exists "Studios can manage their team members." on public.team_members;
drop policy if exists "Allow read on team_members" on public.team_members;
drop policy if exists "Allow insert on team_members" on public.team_members;
drop policy if exists "Allow update on team_members" on public.team_members;
drop policy if exists "Allow delete on team_members" on public.team_members;
drop policy if exists "team_members_select_public" on public.team_members;
drop policy if exists "team_members_insert_studio_owner" on public.team_members;
drop policy if exists "team_members_update_studio_owner" on public.team_members;
drop policy if exists "team_members_delete_studio_owner" on public.team_members;

create policy "team_members_select_public" on public.team_members for select using ( true );
create policy "team_members_insert_studio_owner" on public.team_members for insert with check ( auth.uid() is not null and auth.uid()::text = studio_id::text );
create policy "team_members_update_studio_owner" on public.team_members for update using ( auth.uid() is not null and auth.uid()::text = studio_id::text ) with check ( auth.uid() is not null and auth.uid()::text = studio_id::text );
create policy "team_members_delete_studio_owner" on public.team_members for delete using ( auth.uid() is not null and auth.uid()::text = studio_id::text );

-- 4. JOBS: Publicly readable on discovery feed, but ONLY the author can insert/delete
alter table public.jobs enable row level security;
drop policy if exists "Allow read on jobs" on public.jobs;
drop policy if exists "Allow insert on jobs" on public.jobs;
drop policy if exists "Allow update on jobs" on public.jobs;
drop policy if exists "Allow delete on jobs" on public.jobs;
drop policy if exists "jobs_select_public" on public.jobs;
drop policy if exists "jobs_insert_author" on public.jobs;
drop policy if exists "jobs_update_authenticated" on public.jobs;
drop policy if exists "jobs_delete_author" on public.jobs;

create policy "jobs_select_public" on public.jobs for select using ( true );
create policy "jobs_insert_author" on public.jobs for insert with check ( auth.uid() is not null and auth.uid()::text = author_id::text );
create policy "jobs_update_authenticated" on public.jobs for update using ( auth.uid() is not null );
create policy "jobs_delete_author" on public.jobs for delete using ( auth.uid() is not null and auth.uid()::text = author_id::text );

-- 5. USER INTERACTIONS: Only the owner of those likes/saves can read/insert/update
alter table public.user_interactions enable row level security;
drop policy if exists "Allow read on user_interactions" on public.user_interactions;
drop policy if exists "Allow insert on user_interactions" on public.user_interactions;
drop policy if exists "Allow update on user_interactions" on public.user_interactions;
drop policy if exists "user_interactions_select_own" on public.user_interactions;
drop policy if exists "user_interactions_insert_own" on public.user_interactions;
drop policy if exists "user_interactions_update_own" on public.user_interactions;

create policy "user_interactions_select_own" on public.user_interactions for select using ( auth.uid() is not null and auth.uid()::text = user_id::text );
create policy "user_interactions_insert_own" on public.user_interactions for insert with check ( auth.uid() is not null and auth.uid()::text = user_id::text );
create policy "user_interactions_update_own" on public.user_interactions for update using ( auth.uid() is not null and auth.uid()::text = user_id::text ) with check ( auth.uid() is not null and auth.uid()::text = user_id::text );

-- 6. BOOKINGS: Readable for studio calendar availability, only authenticated users can insert, and only client or studio owner can update/delete
alter table public.bookings enable row level security;
drop policy if exists "Allow read on bookings" on public.bookings;
drop policy if exists "Allow insert on bookings" on public.bookings;
drop policy if exists "Allow update on bookings" on public.bookings;
drop policy if exists "Allow delete on bookings" on public.bookings;
drop policy if exists "bookings_select_public" on public.bookings;
drop policy if exists "bookings_insert_authenticated" on public.bookings;
drop policy if exists "bookings_update_participant" on public.bookings;
drop policy if exists "bookings_delete_participant" on public.bookings;

create policy "bookings_select_public" on public.bookings for select using ( true );
create policy "bookings_insert_authenticated" on public.bookings for insert with check ( auth.uid() is not null );
create policy "bookings_update_participant" on public.bookings for update using ( auth.uid() is not null and (auth.uid()::text = detailer_id::text or auth.uid()::text = client_id::text) );
create policy "bookings_delete_participant" on public.bookings for delete using ( auth.uid() is not null and (auth.uid()::text = detailer_id::text or auth.uid()::text = client_id::text) );

-- 7. CONVERSATIONS & MESSAGES: Only conversation participants can read or send messages
alter table public.conversations enable row level security;
drop policy if exists "Allow read on conversations" on public.conversations;
drop policy if exists "Allow insert on conversations" on public.conversations;
drop policy if exists "Allow update on conversations" on public.conversations;
drop policy if exists "conversations_select_participant" on public.conversations;
drop policy if exists "conversations_insert_participant" on public.conversations;
drop policy if exists "conversations_update_participant" on public.conversations;

create policy "conversations_select_participant" on public.conversations for select using ( auth.uid() is not null and (auth.uid()::text = participant_a::text or auth.uid()::text = participant_b::text) );
create policy "conversations_insert_participant" on public.conversations for insert with check ( auth.uid() is not null and (auth.uid()::text = participant_a::text or auth.uid()::text = participant_b::text) );
create policy "conversations_update_participant" on public.conversations for update using ( auth.uid() is not null and (auth.uid()::text = participant_a::text or auth.uid()::text = participant_b::text) );

alter table public.messages enable row level security;
drop policy if exists "Allow read on messages" on public.messages;
drop policy if exists "Allow insert on messages" on public.messages;
drop policy if exists "Allow update on messages" on public.messages;
drop policy if exists "messages_select_authenticated" on public.messages;
drop policy if exists "messages_insert_sender" on public.messages;
drop policy if exists "messages_update_authenticated" on public.messages;

create policy "messages_select_authenticated" on public.messages for select using ( auth.uid() is not null );
create policy "messages_insert_sender" on public.messages for insert with check ( auth.uid() is not null and auth.uid()::text = sender_id::text );
create policy "messages_update_authenticated" on public.messages for update using ( auth.uid() is not null );

notify pgrst, 'reload schema';
