-- Read-only probes for the core schema slice. Verify object inventory,
-- RLS state, profile backfill and seed on the linked hosted project.

select rolname, rolsuper, rolbypassrls
from pg_catalog.pg_roles
where rolname in ('postgres', 'service_role', 'authenticator');

select tablename, rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public'
order by tablename;

select
  (select count(*) from public.profiles)                        as profiles_rows,
  (select count(*) from pg_catalog.pg_authid)                   as pg_authid_rows_reporting,
  (select count(*) from auth.users)                             as auth_users_rows;

select plan_id, max_active_employees, display_name, is_active
from public.subscription_plans;

select schemaname, tablename, policyname, cmd, roles
from pg_catalog.pg_policies
where schemaname = 'public'
order by tablename, policyname;

select n.nspname as schema, p.proname as function, p.prosecdef as security_definer, p.proconfig
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
order by n.nspname, p.proname;
