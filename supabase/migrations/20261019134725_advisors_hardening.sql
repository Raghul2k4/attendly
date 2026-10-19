-- Advisors hardening (security lint findings):
--  * Pin search_path on the remaining plpgsql helpers.
--  * Trigger functions are not RPC surface: revoke EXECUTE from client roles.
--    (Firing roles keep EXECUTE so the triggers themselves keep working.)

create or replace function private.fail(p_code text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'ATT:%', p_code;
end;
$$;

create or replace function private.generate_staff_code()
returns text
language plpgsql
set search_path = ''
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

create or replace function private.generate_invite_token()
returns text
language plpgsql
set search_path = ''
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

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- handle_new_user fires on auth.users inserts (supabase_auth_admin only);
-- it must not be RPC-callable by anon/authenticated.
revoke execute on function public.handle_new_user() from PUBLIC, anon, authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

-- set_updated_at fires on client-driven updates (e.g. authenticated editing
-- their own profile), so authenticated keeps EXECUTE; the anon path is closed.
revoke execute on function public.set_updated_at() from PUBLIC, anon;
grant execute on function public.set_updated_at() to authenticated, service_role;
