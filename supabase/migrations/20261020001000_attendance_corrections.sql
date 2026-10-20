-- Owner-authorised attendance corrections with an audit trail.
--
-- Rules that this migration enforces on the server:
--   * only the active owner of the session's organisation may correct it;
--   * a reason is always required (5-500 characters, trimmed);
--   * the new check-out must be after the recorded check-in, not in the future,
--     and must fall on the session's work date or the following day (overnight
--     shifts);
--   * the original punch events in public.attendance_events are never touched,
--     and the previous check-out value is preserved in
--     public.attendance_corrections;
--   * every adjustment is written to public.audit_logs with the acting owner.
--
-- The client only sends the wall-clock date and time it wants; the server
-- interprets them in the organisation's IANA timezone, so a phone in another
-- timezone cannot shift the stored value.

-- ---------------------------------------------------------------- corrections
create table if not exists public.attendance_corrections (
  id                     uuid primary key default gen_random_uuid(),
  organisation_id        uuid not null references public.organisations (id) on delete cascade,
  session_id             uuid not null references public.attendance_sessions (id) on delete cascade,
  member_id              uuid not null references public.organisation_members (id) on delete restrict,
  original_check_out_at  timestamptz,
  corrected_check_out_at timestamptz not null,
  reason                 text not null
    check (pg_catalog.length(pg_catalog.btrim(reason)) between 5 and 500),
  actor_user_id          uuid references public.profiles (id) on delete set null,
  created_at             timestamptz not null default now()
);

create index if not exists attendance_corrections_org_created_idx
  on public.attendance_corrections (organisation_id, created_at desc);

create index if not exists attendance_corrections_session_idx
  on public.attendance_corrections (session_id, created_at desc);

-- The session row carries the current (possibly corrected) value plus a marker
-- so reports can label a record without joining the correction history.
alter table public.attendance_sessions
  add column if not exists corrected_at timestamptz;

alter table public.attendance_sessions
  add column if not exists corrected_by uuid references public.profiles (id) on delete set null;

-- Corrections are only reachable through the owner-checked RPCs below, so the
-- table has RLS without any client policy and no client grants.
alter table public.attendance_corrections enable row level security;

revoke all on table public.attendance_corrections from public, anon, authenticated;
grant select, insert, update, delete on table public.attendance_corrections to service_role;

-- ------------------------------------------------------------------- applying
create or replace function public.correct_attendance_checkout(
  p_session uuid,
  p_check_out_date date,
  p_check_out_time time,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_org uuid;
  v_timezone text;
  v_member_id uuid;
  v_work_date date;
  v_check_in_at timestamptz;
  v_check_out_at timestamptz;
  v_reason text;
  v_target timestamptz;
  v_correction_id uuid;
  v_member_name text;
  v_employee_code text;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  v_reason := pg_catalog.btrim(coalesce(p_reason, ''));
  if pg_catalog.length(v_reason) < 5 or pg_catalog.length(v_reason) > 500 then
    perform private.fail('invalid_correction_reason');
  end if;

  if p_check_out_date is null or p_check_out_time is null then
    perform private.fail('invalid_correction_time');
  end if;

  select s.organisation_id into v_org
  from public.attendance_sessions s
  where s.id = p_session;

  if v_org is null then
    perform private.fail('attendance_session_not_found');
  end if;

  if not private.is_active_owner(v_org) then
    perform private.fail('not_org_owner');
  end if;

  select o.timezone into v_timezone
  from public.organisations o
  where o.id = v_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  -- Lock the session so two concurrent corrections cannot both win.
  select s.member_id, s.work_date, s.check_in_at, s.check_out_at
  into v_member_id, v_work_date, v_check_in_at, v_check_out_at
  from public.attendance_sessions s
  where s.id = p_session
  for update;

  -- The client sends a wall-clock time; the organisation timezone decides which
  -- instant that is.
  v_target := (p_check_out_date + p_check_out_time) at time zone v_timezone;

  if v_target <= v_check_in_at then
    perform private.fail('correction_before_check_in');
  end if;

  if v_target > v_now then
    perform private.fail('correction_in_future');
  end if;

  if p_check_out_date < v_work_date or p_check_out_date > v_work_date + 1 then
    perform private.fail('correction_outside_work_date');
  end if;

  if exists (
    select 1
    from public.attendance_corrections c
    where c.session_id = p_session
      and c.corrected_check_out_at = v_target
  ) then
    perform private.fail('correction_already_applied');
  end if;

  if v_check_out_at is not null and v_check_out_at = v_target then
    perform private.fail('correction_no_change');
  end if;

  insert into public.attendance_corrections (
    organisation_id,
    session_id,
    member_id,
    original_check_out_at,
    corrected_check_out_at,
    reason,
    actor_user_id
  ) values (
    v_org,
    p_session,
    v_member_id,
    v_check_out_at,
    v_target,
    v_reason,
    v_caller
  )
  returning id into v_correction_id;

  update public.attendance_sessions
  set check_out_at = v_target,
      corrected_at = v_now,
      corrected_by = v_caller
  where id = p_session;

  perform private.write_audit(
    v_org,
    'attendance_corrected',
    'attendance_session',
    p_session,
    v_reason
  );

  select m.full_name, m.employee_code
  into v_member_name, v_employee_code
  from public.organisation_members m
  where m.id = v_member_id;

  return jsonb_build_object(
    'correction_id', v_correction_id,
    'session_id', p_session,
    'member_id', v_member_id,
    'member_name', v_member_name,
    'employee_code', v_employee_code,
    'work_date', v_work_date,
    'timezone', v_timezone,
    'original_check_out_at', v_check_out_at,
    'corrected_check_out_at', v_target,
    'corrected_check_out_time',
      pg_catalog.to_char(v_target at time zone v_timezone, 'HH24:MI'),
    'duration_seconds', greatest(
      0,
      pg_catalog.floor(
        pg_catalog.date_part('epoch', (v_target - v_check_in_at))
      )::bigint
    ),
    'corrected_at', v_now
  );
end;
$$;

revoke execute on function public.correct_attendance_checkout(uuid, date, time, text)
  from public, anon;
grant execute on function public.correct_attendance_checkout(uuid, date, time, text)
  to authenticated, service_role;

-- ------------------------------------------------------------------ listing
create or replace function public.list_attendance_corrections(
  p_org uuid,
  p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_timezone text;
  v_limit int;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  select o.timezone into v_timezone
  from public.organisations o
  where o.id = p_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);

  return coalesce((
    select pg_catalog.jsonb_agg(row_data.payload order by row_data.created_at desc)
    from (
      select
        c.created_at,
        jsonb_build_object(
          'id', c.id,
          'session_id', c.session_id,
          'member_id', c.member_id,
          'member_name', m.full_name,
          'employee_code', m.employee_code,
          'work_date', s.work_date,
          'workplace_name', w.name,
          'original_check_out_at', c.original_check_out_at,
          'original_check_out_time',
            case when c.original_check_out_at is null then null
                 else pg_catalog.to_char(
                   c.original_check_out_at at time zone v_timezone,
                   'HH24:MI'
                 )
            end,
          'corrected_check_out_at', c.corrected_check_out_at,
          'corrected_check_out_time',
            pg_catalog.to_char(
              c.corrected_check_out_at at time zone v_timezone,
              'HH24:MI'
            ),
          'reason', c.reason,
          'actor_user_id', c.actor_user_id,
          'actor_name', coalesce(pr.full_name, 'Owner'),
          'created_at', c.created_at,
          'created_at_local', pg_catalog.to_char(
            c.created_at at time zone v_timezone,
            'DD Mon YYYY HH24:MI'
          )
        ) as payload
      from public.attendance_corrections c
      join public.attendance_sessions s on s.id = c.session_id
      join public.organisation_members m on m.id = c.member_id
      join public.workplaces w on w.id = s.workplace_id
      left join public.profiles pr on pr.id = c.actor_user_id
      where c.organisation_id = p_org
      order by c.created_at desc
      limit v_limit
    ) row_data
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.list_attendance_corrections(uuid, int)
  from public, anon;
grant execute on function public.list_attendance_corrections(uuid, int)
  to authenticated, service_role;

-- ------------------------------------------------- flag corrected records
-- The report and history payloads are built by a private helper; this adds the
-- correction marker to every session without duplicating that builder.
create or replace function private.with_corrections(p_org uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_flags jsonb := '{}'::jsonb;
  v_sessions jsonb;
begin
  if p_payload is null then
    return p_payload;
  end if;

  select coalesce(
    pg_catalog.jsonb_object_agg(
      grouped.session_id::text,
      pg_catalog.jsonb_build_object(
        'is_corrected', true,
        'corrected_at', grouped.created_at
      )
    ),
    '{}'::jsonb
  )
  into v_flags
  from (
    select c.session_id, max(c.created_at) as created_at
    from public.attendance_corrections c
    where c.organisation_id = p_org
    group by c.session_id
  ) grouped;

  if v_flags = '{}'::jsonb then
    return p_payload;
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      elem.value || coalesce(v_flags -> (elem.value ->> 'id'), '{}'::jsonb)
    ),
    '[]'::jsonb
  )
  into v_sessions
  from pg_catalog.jsonb_array_elements(p_payload -> 'sessions') as elem(value);

  return pg_catalog.jsonb_set(p_payload, '{sessions}', v_sessions);
end;
$$;

revoke execute on function private.with_corrections(uuid, jsonb)
  from public, anon, authenticated, service_role;

-- The two public readers now label corrected records.
create or replace function public.get_my_attendance_history(
  p_org uuid,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_member uuid;
  v_timezone text;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_today date;
  v_from date;
  v_to date;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  select m.id into v_member
  from public.organisation_members m
  where m.organisation_id = p_org
    and m.user_id = v_caller
    and m.role = 'employee'
    and m.status = 'active';

  if v_member is null then
    perform private.fail('not_active_employee');
  end if;

  select o.timezone into v_timezone
  from public.organisations o
  where o.id = p_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  v_today := (v_now at time zone v_timezone)::date;
  v_from := coalesce(p_from, pg_catalog.date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, v_today);

  return private.with_corrections(
    p_org,
    private.attendance_history_payload(p_org, v_from, v_to, v_member, false)
  );
end;
$$;

revoke execute on function public.get_my_attendance_history(uuid, date, date)
  from public, anon;
grant execute on function public.get_my_attendance_history(uuid, date, date)
  to authenticated, service_role;

create or replace function public.get_attendance_report(
  p_org uuid,
  p_from date default null,
  p_to date default null,
  p_member uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_timezone text;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_today date;
  v_from date;
  v_to date;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  if p_member is not null and not exists (
    select 1
    from public.organisation_members m
    where m.id = p_member
      and m.organisation_id = p_org
      and m.role = 'employee'
  ) then
    perform private.fail('member_not_found');
  end if;

  select o.timezone into v_timezone
  from public.organisations o
  where o.id = p_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  v_today := (v_now at time zone v_timezone)::date;
  v_from := coalesce(p_from, pg_catalog.date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, v_today);

  return private.with_corrections(
    p_org,
    private.attendance_history_payload(p_org, v_from, v_to, p_member, true)
  );
end;
$$;

revoke execute on function public.get_attendance_report(uuid, date, date, uuid)
  from public, anon;
grant execute on function public.get_attendance_report(uuid, date, date, uuid)
  to authenticated, service_role;
