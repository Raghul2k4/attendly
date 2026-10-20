-- Attendance history and owner reporting.
--
-- All time formatting and date bucketing happens in PostgreSQL using the
-- organisation's IANA timezone. The client only renders server-provided values,
-- so a phone in another timezone cannot shift a workday or a late arrival.
--
-- Authorization is checked explicitly in each public RPC. A shared private
-- payload helper keeps the employee and owner shapes identical, but it is not
-- executable by client roles and is only called after the caller has been
-- validated.

create index if not exists attendance_sessions_org_work_date_idx
  on public.attendance_sessions (organisation_id, work_date desc, check_in_at desc);

create or replace function private.attendance_history_payload(
  p_org uuid,
  p_from date,
  p_to date,
  p_member uuid,
  p_include_members boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timezone text;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_today date;
  v_sessions jsonb;
  v_summary jsonb;
  v_members jsonb := '[]'::jsonb;
begin
  select o.timezone into v_timezone
  from public.organisations o
  where o.id = p_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  if p_from is null or p_to is null then
    perform private.fail('invalid_date_range');
  end if;

  if p_from > p_to then
    perform private.fail('invalid_date_range');
  end if;

  -- A bounded range keeps one response predictable on a phone connection.
  if p_to - p_from > 366 then
    perform private.fail('date_range_too_large');
  end if;

  v_today := (v_now at time zone v_timezone)::date;

  if p_include_members then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'full_name', m.full_name,
          'employee_code', m.employee_code,
          'status', m.status::text
        )
        order by
          case m.status
            when 'active' then 0
            when 'invited' then 1
            else 2
          end,
          m.full_name,
          m.id
      ),
      '[]'::jsonb
    )
    into v_members
    from public.organisation_members m
    where m.organisation_id = p_org
      and m.role = 'employee';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'member_id', s.member_id,
        'member_name', m.full_name,
        'employee_code', m.employee_code,
        'member_status', m.status::text,
        'workplace_id', s.workplace_id,
        'workplace_name', w.name,
        'work_date', s.work_date,
        'check_in_at', s.check_in_at,
        'check_out_at', s.check_out_at,
        'check_in_time',
          pg_catalog.to_char(s.check_in_at at time zone v_timezone, 'HH24:MI'),
        'check_out_time',
          case when s.check_out_at is null then null
               else pg_catalog.to_char(
                 s.check_out_at at time zone v_timezone,
                 'HH24:MI'
               )
          end,
        'is_late', s.is_late,
        'is_open', s.check_out_at is null,
        'is_stale_open', s.check_out_at is null and s.work_date < v_today,
        'crosses_midnight',
          s.check_out_at is not null
          and (s.check_out_at at time zone v_timezone)::date <> s.work_date,
        'duration_seconds',
          case when s.check_out_at is null then null
               else greatest(
                 0::bigint,
                 pg_catalog.floor(
                   pg_catalog.date_part(
                     'epoch',
                     (s.check_out_at - s.check_in_at)
                   )
                 )::bigint
               )
          end,
        'elapsed_seconds',
          case when s.check_out_at is null then
            greatest(
              0::bigint,
              pg_catalog.floor(
                pg_catalog.date_part('epoch', (v_now - s.check_in_at))
              )::bigint
            )
          else null end
      )
      order by s.work_date desc, s.check_in_at desc
    ),
    '[]'::jsonb
  )
  into v_sessions
  from public.attendance_sessions s
  join public.organisation_members m on m.id = s.member_id
  join public.workplaces w on w.id = s.workplace_id
  where s.organisation_id = p_org
    and s.work_date between p_from and p_to
    and (p_member is null or s.member_id = p_member);

  select jsonb_build_object(
    'session_count', count(*),
    'member_count', count(distinct s.member_id),
    'completed_count', count(*) filter (where s.check_out_at is not null),
    'open_count', count(*) filter (where s.check_out_at is null),
    'late_count', count(*) filter (where s.is_late),
    'total_work_seconds', coalesce(
      sum(
        case when s.check_out_at is null then 0
             else pg_catalog.floor(
               pg_catalog.date_part(
                 'epoch',
                 (s.check_out_at - s.check_in_at)
               )
             )::bigint
        end
      ),
      0
    )::bigint
  )
  into v_summary
  from public.attendance_sessions s
  where s.organisation_id = p_org
    and s.work_date between p_from and p_to
    and (p_member is null or s.member_id = p_member);

  return jsonb_build_object(
    'timezone', v_timezone,
    'today', v_today,
    'from', p_from,
    'to', p_to,
    'members', v_members,
    'sessions', v_sessions,
    'summary', v_summary
  );
end;
$$;

revoke execute on function private.attendance_history_payload(
  uuid, date, date, uuid, boolean
) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------- employee history
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

  return private.attendance_history_payload(
    p_org, v_from, v_to, v_member, false
  );
end;
$$;

revoke execute on function public.get_my_attendance_history(uuid, date, date)
  from public, anon;
grant execute on function public.get_my_attendance_history(uuid, date, date)
  to authenticated, service_role;

-- ---------------------------------------------------------- owner report
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

  return private.attendance_history_payload(
    p_org, v_from, v_to, p_member, true
  );
end;
$$;

revoke execute on function public.get_attendance_report(uuid, date, date, uuid)
  from public, anon;
grant execute on function public.get_attendance_report(uuid, date, date, uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------- owner overview
create or replace function public.get_owner_attendance_overview(p_org uuid)
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
  v_is_working_day boolean := false;
  v_active_employees int;
  v_present_today int;
  v_checked_in_today int;
  v_completed_today int;
  v_late_today int;
  v_unresolved_prior int;
  v_open_sessions jsonb;
  v_recent_sessions jsonb;
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

  v_today := (v_now at time zone v_timezone)::date;

  select exists (
    select 1
    from public.attendance_settings s
    where s.organisation_id = p_org
      and pg_catalog.date_part('isodow', v_today)::smallint
          = any (s.working_days)
  )
  into v_is_working_day;

  select count(*) into v_active_employees
  from public.organisation_members m
  where m.organisation_id = p_org
    and m.role = 'employee'
    and m.status = 'active';

  select
    count(*) filter (where s.check_out_at is null)::int,
    count(*) filter (where s.check_out_at is not null)::int,
    count(*) filter (where s.is_late)::int
  into v_checked_in_today, v_completed_today, v_late_today
  from public.attendance_sessions s
  join public.organisation_members m on m.id = s.member_id
  where s.organisation_id = p_org
    and s.work_date = v_today
    and m.role = 'employee'
    and m.status = 'active';

  select count(distinct s.member_id) into v_present_today
  from public.attendance_sessions s
  join public.organisation_members m on m.id = s.member_id
  where s.organisation_id = p_org
    and s.work_date = v_today
    and m.role = 'employee'
    and m.status = 'active';

  select count(*) into v_unresolved_prior
  from public.attendance_sessions s
  where s.organisation_id = p_org
    and s.check_out_at is null
    and s.work_date < v_today;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'member_id', s.member_id,
        'member_name', m.full_name,
        'employee_code', m.employee_code,
        'member_status', m.status::text,
        'workplace_id', s.workplace_id,
        'workplace_name', w.name,
        'work_date', s.work_date,
        'check_in_at', s.check_in_at,
        'check_out_at', null,
        'check_in_time',
          pg_catalog.to_char(s.check_in_at at time zone v_timezone, 'HH24:MI'),
        'check_out_time', null,
        'is_late', s.is_late,
        'is_open', true,
        'is_stale_open', s.work_date < v_today,
        'crosses_midnight', false,
        'duration_seconds', null,
        'elapsed_seconds',
          greatest(
            0::bigint,
            pg_catalog.floor(
              pg_catalog.date_part('epoch', (v_now - s.check_in_at))
            )::bigint
          )
      )
      order by s.check_in_at
    ),
    '[]'::jsonb
  )
  into v_open_sessions
  from public.attendance_sessions s
  join public.organisation_members m on m.id = s.member_id
  join public.workplaces w on w.id = s.workplace_id
  where s.organisation_id = p_org
    and s.check_out_at is null;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'member_id', s.member_id,
        'member_name', m.full_name,
        'employee_code', m.employee_code,
        'member_status', m.status::text,
        'workplace_id', s.workplace_id,
        'workplace_name', w.name,
        'work_date', s.work_date,
        'check_in_at', s.check_in_at,
        'check_out_at', s.check_out_at,
        'check_in_time',
          pg_catalog.to_char(s.check_in_at at time zone v_timezone, 'HH24:MI'),
        'check_out_time',
          case when s.check_out_at is null then null
               else pg_catalog.to_char(
                 s.check_out_at at time zone v_timezone,
                 'HH24:MI'
               )
          end,
        'is_late', s.is_late,
        'is_open', s.check_out_at is null,
        'is_stale_open', s.check_out_at is null and s.work_date < v_today,
        'crosses_midnight',
          s.check_out_at is not null
          and (s.check_out_at at time zone v_timezone)::date <> s.work_date,
        'duration_seconds',
          case when s.check_out_at is null then null
               else greatest(
                 0::bigint,
                 pg_catalog.floor(
                   pg_catalog.date_part(
                     'epoch',
                     (s.check_out_at - s.check_in_at)
                   )
                 )::bigint
               )
          end,
        'elapsed_seconds',
          case when s.check_out_at is null then
            greatest(
              0::bigint,
              pg_catalog.floor(
                pg_catalog.date_part('epoch', (v_now - s.check_in_at))
              )::bigint
            )
          else null end
      )
      order by coalesce(s.check_out_at, s.check_in_at) desc
    ),
    '[]'::jsonb
  )
  into v_recent_sessions
  from (
    select s.*
    from public.attendance_sessions s
    where s.organisation_id = p_org
    order by coalesce(s.check_out_at, s.check_in_at) desc
    limit 6
  ) s
  join public.organisation_members m on m.id = s.member_id
  join public.workplaces w on w.id = s.workplace_id;

  return jsonb_build_object(
    'timezone', v_timezone,
    'server_time', v_now,
    'today', v_today,
    'is_working_day', v_is_working_day,
    'active_employee_count', v_active_employees,
    'present_today_count', v_present_today,
    'checked_in_now_count', v_checked_in_today,
    'completed_today_count', v_completed_today,
    'late_today_count', v_late_today,
    'unresolved_prior_count', v_unresolved_prior,
    'no_record_today_count',
      greatest(0, v_active_employees - v_present_today),
    'open_sessions', v_open_sessions,
    'recent_sessions', v_recent_sessions
  );
end;
$$;

revoke execute on function public.get_owner_attendance_overview(uuid)
  from public, anon;
grant execute on function public.get_owner_attendance_overview(uuid)
  to authenticated, service_role;
