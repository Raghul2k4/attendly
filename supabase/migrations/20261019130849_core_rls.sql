-- Attendance — Row Level Security for the core schema.
-- Model:
--  - employees: read own profile, own memberships, plus shared org facts
--               (org, workplaces, settings) needed for punches
--  - owners: everything inside the organisation they own
--  - membership writes happen only through backend functions (no direct
--    INSERT/UPDATE policies on organisation_members)
-- Policy predicates use private.* STABLE definer helpers: no RLS recursion
-- and one evaluation per statement (not per row).

-- Plain ENABLE (not FORCE): policies must stay off the owner path so the
-- definer helpers and the profile-creation trigger keep working, and FORCE
-- would reintroduce RLS recursion through them. anon/authenticated never
-- own these tables, so enforcement is unaffected.
alter table public.subscription_plans   enable row level security;
alter table public.profiles             enable row level security;
alter table public.organisations        enable row level security;
alter table public.organisation_members enable row level security;
alter table public.workplaces           enable row level security;
alter table public.attendance_settings  enable row level security;
alter table public.audit_logs           enable row level security;

-- Plans: non-sensitive configuration, readable when active.
create policy plans_select on public.subscription_plans
  for select to authenticated
  using ( is_active );

-- Profiles: own row only.
create policy profiles_select_own on public.profiles
  for select to authenticated
  using ( (select auth.uid()) = id );

create policy profiles_update_own on public.profiles
  for update to authenticated
  using ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

-- Members: own row, or (owner view) all rows of an org they own.
create policy members_select_own_or_owner on public.organisation_members
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.is_active_owner(organisation_id)
  );

-- Organisation: visible to invited/active members; owner-only update.
create policy organisations_select_members on public.organisations
  for select to authenticated
  using ( private.is_member(id, '{invited,active}') );

create policy organisations_update_owner on public.organisations
  for update to authenticated
  using ( owner_user_id = (select auth.uid()) )
  with check ( owner_user_id = (select auth.uid()) );

-- Workplaces: read by members; writes by the owner only.
create policy workplaces_select_members on public.workplaces
  for select to authenticated
  using ( private.is_member(organisation_id, '{invited,active}') );

create policy workplaces_insert_owner on public.workplaces
  for insert to authenticated
  with check ( private.is_active_owner(organisation_id) );

create policy workplaces_update_owner on public.workplaces
  for update to authenticated
  using ( private.is_active_owner(organisation_id) )
  with check ( private.is_active_owner(organisation_id) );

-- Attendance settings: read by members; update by the owner only.
create policy attendance_settings_select_members on public.attendance_settings
  for select to authenticated
  using ( private.is_member(organisation_id, '{invited,active}') );

create policy attendance_settings_update_owner on public.attendance_settings
  for update to authenticated
  using ( private.is_active_owner(organisation_id) )
  with check ( private.is_active_owner(organisation_id) );

-- Audit trail: owner-readable; writes happen in definer functions only.
create policy audit_logs_select_owner on public.audit_logs
  for select to authenticated
  using ( private.is_active_owner(organisation_id) );
