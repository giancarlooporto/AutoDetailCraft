-- ============================================================================
-- Owner Master PIN security (server-authoritative)
-- ----------------------------------------------------------------------------
-- * The raw PIN is NEVER stored. Only a bcrypt hash (pgcrypto crypt + gen_salt('bf')).
-- * The owner_security table has RLS enabled with NO policies, so it can not be
--   read or written directly from the browser (anon/authenticated roles).
--   All access goes through SECURITY DEFINER RPC functions bound to auth.uid().
-- * Brute-force shield: 5 failed attempts => PIN locked for 15 minutes.
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.owner_security (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  pin_hash         text not null,
  failed_attempts  int not null default 0,
  locked_until     timestamptz,
  updated_at       timestamptz not null default now()
);

alter table public.owner_security enable row level security;
-- Intentionally no policies: direct table access is denied for client roles.
revoke all on public.owner_security from anon, authenticated;

-- Remove any legacy plaintext PIN column if it ever existed on profiles.
alter table public.profiles drop column if exists owner_pin;

-- ----------------------------------------------------------------------------
-- owner_pin_status(): { has_pin, locked_until }
-- ----------------------------------------------------------------------------
create or replace function public.owner_pin_status()
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  rec public.owner_security;
begin
  if auth.uid() is null then
    return json_build_object('has_pin', false, 'error', 'not_authenticated');
  end if;
  select * into rec from public.owner_security where user_id = auth.uid();
  return json_build_object(
    'has_pin', rec.user_id is not null,
    'locked_until', rec.locked_until
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- set_owner_pin(p_current, p_new): first-time create (p_current ignored) or change
-- ----------------------------------------------------------------------------
create or replace function public.set_owner_pin(p_current text, p_new text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  rec public.owner_security;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if p_new is null or p_new !~ '^[0-9]{4}$' then
    return json_build_object('ok', false, 'error', 'invalid_format');
  end if;

  select * into rec from public.owner_security where user_id = auth.uid() for update;

  if rec.user_id is null then
    insert into public.owner_security(user_id, pin_hash)
    values (auth.uid(), crypt(p_new, gen_salt('bf', 10)));
    return json_build_object('ok', true, 'created', true);
  end if;

  if rec.locked_until is not null and rec.locked_until > now() then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', rec.locked_until);
  end if;

  if p_current is null or crypt(p_current, rec.pin_hash) <> rec.pin_hash then
    update public.owner_security
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else null end,
           updated_at = now()
     where user_id = auth.uid();
    return json_build_object('ok', false, 'error', 'wrong_pin');
  end if;

  update public.owner_security
     set pin_hash = crypt(p_new, gen_salt('bf', 10)),
         failed_attempts = 0,
         locked_until = null,
         updated_at = now()
   where user_id = auth.uid();
  return json_build_object('ok', true);
end;
$$;

-- ----------------------------------------------------------------------------
-- verify_owner_pin(p_pin): { ok, remaining, locked_until }
-- ----------------------------------------------------------------------------
create or replace function public.verify_owner_pin(p_pin text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  rec public.owner_security;
  attempts int;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select * into rec from public.owner_security where user_id = auth.uid() for update;
  if rec.user_id is null then
    return json_build_object('ok', false, 'error', 'no_pin');
  end if;

  if rec.locked_until is not null and rec.locked_until > now() then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', rec.locked_until);
  end if;

  if p_pin is not null and crypt(p_pin, rec.pin_hash) = rec.pin_hash then
    update public.owner_security
       set failed_attempts = 0, locked_until = null, updated_at = now()
     where user_id = auth.uid();
    return json_build_object('ok', true);
  end if;

  attempts := rec.failed_attempts + 1;
  update public.owner_security
     set failed_attempts = case when attempts >= 5 then 0 else attempts end,
         locked_until = case when attempts >= 5 then now() + interval '15 minutes' else null end,
         updated_at = now()
   where user_id = auth.uid();

  if attempts >= 5 then
    return json_build_object('ok', false, 'error', 'locked', 'locked_until', now() + interval '15 minutes');
  end if;
  return json_build_object('ok', false, 'error', 'wrong_pin', 'remaining', 5 - attempts);
end;
$$;

revoke all on function public.owner_pin_status() from public, anon;
revoke all on function public.set_owner_pin(text, text) from public, anon;
revoke all on function public.verify_owner_pin(text) from public, anon;
grant execute on function public.owner_pin_status() to authenticated;
grant execute on function public.set_owner_pin(text, text) to authenticated;
grant execute on function public.verify_owner_pin(text) to authenticated;
