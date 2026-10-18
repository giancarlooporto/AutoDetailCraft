-- ============================================================================
-- Migration: 20261018_team_members_invite_columns.sql
-- Purpose: Production-grade Staff Security & Invitation System (Server-Authoritative)
--   1. Cleans up any plaintext pin / password / invite_token columns from
--      public.team_members so public SELECT queries NEVER expose credentials.
--   2. Stores bcrypt-hashed PINs, bcrypt-hashed passwords, and SHA-256 hashed
--      invitation tokens inside a locked-down `public.staff_security` table
--      (RLS enabled, zero client policies, direct read/write revoked).
--   3. Exposes lightweight SECURITY DEFINER RPCs for:
--      - upsert_staff_security (owner sets staff PIN / invite token)
--      - accept_staff_invite_rpc (staff accepts invite token & sets bcrypt password)
--      - verify_staff_pin_rpc (shop tablet 4-digit PIN login)
--      - verify_staff_login_rpc (staff email + password login)
-- ============================================================================

create extension if not exists pgcrypto;

-- 1. Ensure non-sensitive operational columns exist on public.team_members
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

-- 2. Create locked-down staff_security table BEFORE dropping legacy columns
create table if not exists public.staff_security (
  member_id         text primary key references public.team_members(id) on delete cascade,
  studio_id         uuid not null references public.profiles(id) on delete cascade,
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
      id,
      studio_id,
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

-- 3. DROP plaintext credential columns from public.team_members (cleans up previous script)
alter table public.team_members
  drop column if exists pin,
  drop column if exists password,
  drop column if exists invite_token;

-- ============================================================================
-- RPC 1: upsert_staff_security (Called by Studio Owner when adding/editing staff)
-- ============================================================================
create or replace function public.upsert_staff_security(
  p_member_id text,
  p_studio_id uuid,
  p_pin text default null,
  p_invite_token text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null or auth.uid() <> p_studio_id then
    return json_build_object('ok', false, 'error', 'unauthorized');
  end if;

  insert into public.staff_security (
    member_id,
    studio_id,
    pin_hash,
    invite_token_hash,
    updated_at
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

-- ============================================================================
-- RPC 2: accept_staff_invite_rpc (Called when staff clicks invite link & sets password)
-- ============================================================================
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

  -- Hash password with bcrypt and consume (invalidate) the one-time invite token
  update public.staff_security
     set password_hash = crypt(trim(p_new_password), gen_salt('bf', 10)),
         invite_token_hash = null,
         failed_attempts = 0,
         locked_until = null,
         updated_at = now()
   where member_id = v_sec.member_id;

  update public.team_members
     set invite_status = 'accepted'
   where id = v_sec.member_id
  returning * into v_member;

  return json_build_object(
    'ok', true,
    'studio_id', v_sec.studio_id,
    'member', row_to_json(v_member)
  );
end;
$$;

-- ============================================================================
-- RPC 3: verify_staff_pin_rpc (Shop Tablet 4-digit PIN check with brute-force shield)
-- ============================================================================
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
    select * into v_member from public.team_members where id = p_member_id;
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

-- ============================================================================
-- RPC 4: verify_staff_login_rpc (Personal Device Email + Password login)
-- ============================================================================
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

  select * into v_sec from public.staff_security where member_id = v_member.id for update;
  if v_sec.member_id is null or v_sec.password_hash is null then
    return json_build_object('ok', false, 'error', 'invalid_credentials');
  end if;

  if v_sec.locked_until is not null and v_sec.locked_until > now() then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', v_sec.locked_until);
  end if;

  if p_password is not null and crypt(trim(p_password), v_sec.password_hash) = v_sec.password_hash then
    update public.staff_security
       set failed_attempts = 0, locked_until = null, updated_at = now()
     where member_id = v_member.id;
    return json_build_object('ok', true, 'studio_id', v_member.studio_id, 'member', row_to_json(v_member));
  end if;

  v_attempts := v_sec.failed_attempts + 1;
  update public.staff_security
     set failed_attempts = case when v_attempts >= 5 then 0 else v_attempts end,
         locked_until = case when v_attempts >= 5 then now() + interval '15 minutes' else null end,
         updated_at = now()
   where member_id = v_member.id;

  return json_build_object('ok', false, 'error', 'invalid_credentials');
end;
$$;

revoke all on function public.upsert_staff_security(text, uuid, text, text) from public, anon;
grant execute on function public.upsert_staff_security(text, uuid, text, text) to authenticated;
grant execute on function public.accept_staff_invite_rpc(text, text) to anon, authenticated;
grant execute on function public.verify_staff_pin_rpc(text, text) to anon, authenticated;
grant execute on function public.verify_staff_login_rpc(text, text) to anon, authenticated;
