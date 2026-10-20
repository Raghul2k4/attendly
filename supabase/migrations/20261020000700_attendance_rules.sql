-- Attendance rules: late-arrival classification and an audit trail for the
-- owner-editable policy itself.
--
-- Lateness is classified once, when the check-in session is inserted, so a
-- later change to the start time or grace period cannot rewrite history.

alter table public.attendance_sessions
  add column is_late boolean not null default false;

-- The punch function inserts sessions only; classify at insert time using the
-- organisation timezone and the policy that was in force for that punch.
create or replace function private.set_attendance_session_lateness()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timezone text;
  v_working_days smallint[];
  v_start_time time;
  v_grace_minutes int;
begin
  select o.timezone, s.working_days, s.start_time, s.grace_minutes
    into v_timezone, v_working_days, v_start_time, v_grace_minutes
  from public.organisations o
  join public.attendance_settings s on s.organisation_id = o.id
  where o.id = new.organisation_id;

  if v_timezone is not null
     and pg_catalog.date_part('isodow', new.work_date)::smallint
         = any (v_working_days)
     and (new.check_in_at at time zone v_timezone)::time
         > v_start_time
           + pg_catalog.make_interval(mins => v_grace_minutes)
  then
    new.is_late := true;
  end if;

  return new;
end;
$$;

revoke execute on function private.set_attendance_session_lateness()
  from public, anon, authenticated, service_role;

create trigger attendance_sessions_set_lateness
  before insert on public.attendance_sessions
  for each row execute function private.set_attendance_session_lateness();

-- Include the stored classification in every session JSON response.
create or replace function private.attendance_session_json(p_session_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select case when s.id is null then null else jsonb_build_object(
    'id', s.id,
    'work_date', s.work_date,
    'check_in_at', s.check_in_at,
    'check_out_at', s.check_out_at,
    'is_late', s.is_late,
    'check_in_time', pg_catalog.to_char(s.check_in_at at time zone o.timezone, 'HH24:MI'),
    'check_out_time',
      case when s.check_out_at is null then null
           else pg_catalog.to_char(s.check_out_at at time zone o.timezone, 'HH24:MI')
      end
  ) end
  from public.attendance_sessions s
  join public.organisations o on o.id = s.organisation_id
  where s.id = p_session_id;
$$;

revoke execute on function private.attendance_session_json(uuid)
  from PUBLIC, anon, authenticated, service_role;

-- Settings are written directly by owners under RLS, so capture policy changes
-- in the audit trail from a trigger rather than trusting the client to log.
create or replace function private.audit_attendance_settings_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.app_punch_enabled is distinct from old.app_punch_enabled
     or new.qr_punch_enabled is distinct from old.qr_punch_enabled
     or new.working_days is distinct from old.working_days
     or new.start_time is distinct from old.start_time
     or new.grace_minutes is distinct from old.grace_minutes
     or new.max_accuracy_meters is distinct from old.max_accuracy_meters
  then
    perform private.write_audit(
      new.organisation_id,
      'attendance_settings_updated',
      'attendance_settings',
      new.organisation_id,
      null
    );
  end if;
  return new;
end;
$$;

revoke execute on function private.audit_attendance_settings_changes()
  from public, anon, authenticated, service_role;

create trigger attendance_settings_audit_changes
  after update on public.attendance_settings
  for each row execute function private.audit_attendance_settings_changes();
