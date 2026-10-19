-- Attendance — core schema + backend helpers (organisations, members,
-- workplaces, settings, plans). Attendance sessions/events/QR come later.
--
-- private.* helpers called from RLS policy expressions run with the CALLER's
-- rights for the invocation itself (SECURITY DEFINER only relaxes access to
-- objects inside the body), so authenticated needs USAGE + EXECUTE on the two
-- policy predicates.

create schema if not exists private;
revoke all on schema private from PUBLIC, anon, authenticated;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------- helpers

-- Stable error marker consumed by the Flutter error mapper ("ATT:code").
create or replace function private.fail(p_code text)
returns void
language plpgsql
as $$
begin
  raise exception 'ATT:%', p_code;
end;
$$;

-- Protected-column guards. These run server-side on every client update.
-- Protected-column guards. SECURITY DEFINER so `private.fail` runs as the
-- owner (EXECUTE is revoked from client roles); bodies are fixed logic.
create or replace function private.guard_organisations_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.plan_id is distinct from old.plan_id then
    perform private.fail('plan_change_not_allowed');
  end if;
  if new.owner_user_id is distinct from old.owner_user_id then
    perform private.fail('owner_change_not_allowed');
  end if;
  if new.created_at is distinct from old.created_at then
    perform private.fail('protected_field_change_not_allowed');
  end if;
  if new.timezone is distinct from old.timezone
    and not exists (
      select 1 from pg_catalog.pg_timezone_names where name = new.timezone
    ) then
    perform private.fail('unknown_timezone');
  end if;
  return new;
end;
$$;

create or replace function private.guard_no_org_reassign()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.organisation_id is distinct from old.organisation_id then
    perform private.fail('org_reassignment_not_allowed');
  end if;
  return new;
end;
$$;

-- Account deletion must not strand active memberships (seat leak) or trip
-- the status check: free the seat BEFORE the FK's ON DELETE SET NULL fires.
create or replace function private.handle_profile_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.organisation_members
  set status = 'inactive'
  where user_id = old.id
    and role = 'employee';
  return old;
end;
$$;

create or replace function private.write_audit(
  p_org uuid, p_action text, p_target_type text, p_target_id uuid, p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_logs
    (organisation_id, actor_user_id, action, target_type, target_id, reason)
  values (p_org, (select auth.uid()), p_action, p_target_type, p_target_id, p_reason);
end;
$$;

-- ~39-bit staff code (XXXX-XXXX) from a 31-symbol, ambiguity-free alphabet.
-- Core pg_catalog functions keep this extension-free and dependency-proof.
create or replace function private.generate_staff_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes constant bytea :=
    pg_catalog.decode(pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''), 'hex');
  v_code text := '';
  i int;
begin
  for i in 0..7 loop
    v_code := v_code || substr(alphabet, 1 + (pg_catalog.get_byte(v_bytes, i) % length(alphabet)), 1);
  end loop;
  return substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4);
end;
$$;

-- One-time invite token: 20 symbols x 31-symbol alphabet ~= 99 bits, derived
-- from core PRNG material. The RAW token is returned exactly once by
-- invite_employee and never stored; only its SHA-256 hex is kept.
create or replace function private.generate_invite_token()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes constant bytea :=
    pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.gen_random_uuid()::text, 'UTF8'));
  v_code text := '';
  i int;
begin
  for i in 0..19 loop
    v_code := v_code || substr(alphabet, 1 + (pg_catalog.get_byte(v_bytes, i) % length(alphabet)), 1);
  end loop;
  return substr(v_code, 1, 5) || '-' || substr(v_code, 6, 5) || '-'
      || substr(v_code, 11, 5) || '-' || substr(v_code, 16, 5);
end;
$$;

create or replace function private.hash_invite_token(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(
    pg_catalog.sha256(pg_catalog.convert_to(p_token, 'UTF8')),
    'hex'
  );
$$;

-- Single source of truth for token normalization (case, dashes, whitespace).
-- BOTH the stored hash (invite) and the claim-time hash must apply it.
create or replace function private.normalize_invite_token(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(pg_catalog.regexp_replace(coalesce(p_token, ''), '[^0-9A-Za-z]', '', 'g'));
$$;

-- ---------------------------------------------------------------- enums
create type public.org_member_role as enum ('owner', 'employee');
create type public.org_member_status as enum ('invited', 'active', 'inactive');

-- ---------------------------------------------------------------- plans
-- Server-configured entitlements. Seeded here (free pilot). Later paid plans
-- are added as rows — commercial changes never require code changes.
create table public.subscription_plans (
  plan_id              text primary key,
  max_active_employees int not null check (max_active_employees between 1 and 1000),
  display_name         text not null,
  is_active            boolean not null default true,
  created_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(btrim(full_name)) between 1 and 80),
  timezone   text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- orgs
create table public.organisations (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(btrim(name)) between 1 and 80),
  owner_user_id uuid not null references public.profiles (id) on delete cascade,
  timezone      text not null default 'UTC',
  plan_id       text not null references public.subscription_plans (plan_id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index organisations_owner_unique
  on public.organisations (owner_user_id);

-- ---------------------------------------------------------------- members
-- employee_code = permanent readable identifier (shown, not secret).
-- claim_token_hash = SHA-256 of the one-time invite token; the raw token is
-- delivered once through invite_employee and never persisted.
create table public.organisation_members (
  id              uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations (id) on delete cascade,
  user_id         uuid references public.profiles (id) on delete set null,
  role            public.org_member_role not null,
  status          public.org_member_status not null default 'invited',
  full_name       text not null check (char_length(btrim(full_name)) between 1 and 80),
  employee_code   text,
  claim_token_hash text,
  joined_at       timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Unclaimed invitations carry no user; active/inactive rows may lose their
  -- user through account deletion (SET NULL) without blocking it.
  constraint members_invited_has_no_user
    check (status <> 'invited' or user_id is null),
  constraint members_code_only_for_employees
    check (role = 'employee' or employee_code is null),
  constraint members_joined_when_active
    check (status <> 'active' or joined_at is not null)
);

-- One membership per user per organisation.
create unique index members_org_user_unique
  on public.organisation_members (organisation_id, user_id)
  where user_id is not null;

-- Codes unique within an organisation.
create unique index members_org_code_unique
  on public.organisation_members (organisation_id, employee_code)
  where employee_code is not null;

-- Invite tokens are globally unique (one token = one invitation).
create unique index members_claim_token_unique
  on public.organisation_members (claim_token_hash)
  where claim_token_hash is not null;

-- An employee holds at most one active membership anywhere in the product.
create unique index members_user_one_active_employee
  on public.organisation_members (user_id)
  where role = 'employee' and status = 'active';

create index members_org_idx on public.organisation_members (organisation_id);

-- ---------------------------------------------------------------- policy predicates
-- SECURITY DEFINER keeps these off the RLS recursion path (they read
-- organisation_members while policies on that very table are being
-- evaluated). EXECUTE for authenticated is granted further below.
create or replace function private.is_active_owner(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.organisation_members m
    where m.organisation_id = p_org
      and m.user_id = (select auth.uid())
      and m.role = 'owner'
      and m.status = 'active'
  );
$$;

-- Caller is a member of the organisation in any of the given statuses.
create or replace function private.is_member(p_org uuid, p_statuses text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.organisation_members m
    where m.organisation_id = p_org
      and m.user_id = (select auth.uid())
      and m.status::text = any (p_statuses)
  );
$$;

revoke execute on function private.fail(text),
             private.guard_organisations_update(),
             private.guard_no_org_reassign(),
             private.handle_profile_deleted(),
             private.write_audit(uuid, text, text, uuid, text),
             private.generate_staff_code(),
             private.generate_invite_token(),
             private.hash_invite_token(text),
             private.normalize_invite_token(text)
  from PUBLIC, anon, authenticated, service_role;

-- Policy helpers must be callable by the roles evaluating the policies.
grant execute on function private.is_active_owner(uuid) to authenticated;
grant execute on function private.is_member(uuid, text[]) to authenticated;

-- ---------------------------------------------------------------- workplaces
create table public.workplaces (
  id              uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations (id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 1 and 80),
  latitude        numeric(9, 6) not null check (latitude between -90 and 90),
  longitude       numeric(9, 6) not null check (longitude between -180 and 180),
  radius_meters   int not null check (radius_meters between 20 and 5000),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index workplaces_org_idx on public.workplaces (organisation_id);

-- ---------------------------------------------------------------- settings
create table public.attendance_settings (
  organisation_id     uuid primary key references public.organisations (id) on delete cascade,
  app_punch_enabled   boolean not null default true,
  qr_punch_enabled    boolean not null default false,
  working_days        smallint[] not null default '{1,2,3,4,5}'
                        -- subset semantics only; consumers use "= any(...)"
                        -- membership tests, so duplicate elements are harmless
                        -- (CHECK constraints cannot contain subqueries, so
                        -- de-duplication is enforced in the settings function).
                        check (working_days <@ '{1,2,3,4,5,6,7}'::smallint[]
                               and cardinality(working_days) between 1 and 7),
  start_time          time not null default '09:00',
  grace_minutes       smallint not null default 10 check (grace_minutes between 0 and 120),
  max_accuracy_meters int not null default 50 check (max_accuracy_meters between 5 and 500),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------- audit
create table public.audit_logs (
  id              uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations (id) on delete cascade,
  actor_user_id   uuid references public.profiles (id) on delete set null,
  action          text not null,
  target_type     text not null,
  target_id       uuid,
  reason          text,
  created_at      timestamptz not null default now()
);

create index audit_logs_org_created_idx
  on public.audit_logs (organisation_id, created_at desc);

-- ---------------------------------------------------------------- triggers
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger organisations_set_updated_at
  before update on public.organisations
  for each row execute function public.set_updated_at();

create trigger organisations_guard_update
  before update on public.organisations
  for each row execute function private.guard_organisations_update();

create trigger members_set_updated_at
  before update on public.organisation_members
  for each row execute function public.set_updated_at();

create trigger workplaces_set_updated_at
  before update on public.workplaces
  for each row execute function public.set_updated_at();

create trigger workplaces_no_org_reassign
  before update on public.workplaces
  for each row execute function private.guard_no_org_reassign();

create trigger attendance_settings_set_updated_at
  before update on public.attendance_settings
  for each row execute function public.set_updated_at();

create trigger attendance_settings_no_org_reassign
  before update on public.attendance_settings
  for each row execute function private.guard_no_org_reassign();

create trigger profiles_member_cleanup_before_delete
  before delete on public.profiles
  for each row execute function private.handle_profile_deleted();

-- Every new auth user gets a profile row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'New user')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: users who signed up before this migration have no profile row
-- (the trigger only fires on future inserts). Without this, the first
-- create_organisation call from an existing account fails on the FK.
insert into public.profiles (id, full_name)
select u.id,
       coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), 'New user')
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------- seed
insert into public.subscription_plans (plan_id, max_active_employees, display_name)
values ('free', 15, 'Free')
on conflict (plan_id) do nothing;
