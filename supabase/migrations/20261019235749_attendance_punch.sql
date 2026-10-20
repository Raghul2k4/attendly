-- Attendance punch pipeline.
--
-- Design notes:
--  * Sessions and events are written ONLY by SECURITY DEFINER functions; the
--    client has SELECT policies and no write policies/privileges.
--  * Timestamps are always server-generated (clock_timestamp()) and the local
--    work date is derived from the organisation's IANA timezone.
--  * One session per employee per local work date, and at most one OPEN
--    session per employee. Punch-out closes the open session even after
--    midnight, so overnight sessions cannot strand an employee checked in.
--  * Rejected attempts are recorded as append-only evidence (location,
--    accuracy, distance) and returned as a structured result rather than an
--    exception. Invalid configuration (method disabled, no active employee)
--    raises ATT:<code> and is not logged.
--  * Idempotency: (member_id, idempotency_key) is unique; a replay returns the
--    original event unchanged.
--  * Client GPS is evidence, not proof of physical presence. The server
--    enforces the geofence and accuracy threshold, but a determined attacker
--    with a mocked location can still spoof coordinates.

-- ---------------------------------------------------------------- sessions
create table public.attendance_sessions (
  id              uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations (id) on delete cascade,
  member_id       uuid not null references public.organisation_members (id) on delete restrict,
  workplace_id    uuid not null references public.workplaces (id) on delete restrict,
  work_date       date not null,
  check_in_at     timestamptz not null,
  check_out_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint attendance_sessions_time_order
    check (check_out_at is null or check_out_at >= check_in_at)
);

-- One completed/open session per employee per local work date.
create unique index attendance_sessions_member_day_unique
  on public.attendance_sessions (organisation_id, member_id, work_date);

-- At most one open session per employee, regardless of date (overnight close).
create unique index attendance_sessions_one_open_unique
  on public.attendance_sessions (organisation_id, member_id)
  where check_out_at is null;

create index attendance_sessions_org_check_in_idx
  on public.attendance_sessions (organisation_id, check_in_at desc);

create index attendance_sessions_member_check_in_idx
  on public.attendance_sessions (member_id, check_in_at desc);

create trigger attendance_sessions_set_updated_at
  before update on public.attendance_sessions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- events
create table public.attendance_events (
  id                   uuid primary key default gen_random_uuid(),
  organisation_id      uuid not null references public.organisations (id) on delete cascade,
  member_id            uuid not null references public.organisation_members (id) on delete restrict,
  session_id           uuid references public.attendance_sessions (id) on delete set null,
  workplace_id         uuid references public.workplaces (id) on delete set null,
  event_type           text not null check (event_type in ('punch_in', 'punch_out')),
  method               text not null check (method in ('app', 'qr')),
  server_time          timestamptz not null,
  latitude             double precision,
  longitude            double precision,
  accuracy_meters      double precision check (accuracy_meters is null or accuracy_meters >= 0),
  distance_meters      double precision check (distance_meters is null or distance_meters >= 0),
  validation_result    text not null check (validation_result in ('accepted', 'rejected')),
  rejection_reason     text,
  idempotency_key      uuid not null,
  created_at           timestamptz not null default now(),
  constraint attendance_events_location_ranges
    check (
      (latitude is null or latitude between -90 and 90)
      and (longitude is null or longitude between -180 and 180)
    ),
  constraint attendance_events_decision_consistent
    check (
      (validation_result = 'accepted' and rejection_reason is null)
      or (validation_result = 'rejected' and rejection_reason is not null)
    ),
  constraint attendance_events_member_key_unique
    unique (member_id, idempotency_key)
);

create index attendance_events_org_time_idx
  on public.attendance_events (organisation_id, server_time desc);

create index attendance_events_member_time_idx
  on public.attendance_events (member_id, server_time desc);

create index attendance_events_org_rejected_idx
  on public.attendance_events (organisation_id, server_time desc)
  where validation_result = 'rejected';

-- ---------------------------------------------------------------- RLS
alter table public.attendance_sessions enable row level security;
alter table public.attendance_events   enable row level security;

-- No client writes. SECURITY DEFINER functions run as the table owner and are
-- unaffected by these revokes.
revoke insert, update, delete on public.attendance_sessions from anon, authenticated;
revoke insert, update, delete on public.attendance_events   from anon, authenticated;

create or replace function private.is_own_active_member(p_member uuid, p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members m
    where m.id = p_member
      and m.organisation_id = p_org
      and m.user_id = (select auth.uid())
      and m.role = 'employee'
      and m.status = 'active'
  );
$$;

grant execute on function private.is_own_active_member(uuid, uuid) to authenticated;

create policy attendance_sessions_select_own_or_owner
  on public.attendance_sessions
  for select to authenticated
  using (
    private.is_active_owner(organisation_id)
    or private.is_own_active_member(member_id, organisation_id)
  );

create policy attendance_events_select_own_or_owner
  on public.attendance_events
  for select to authenticated
  using (
    private.is_active_owner(organisation_id)
    or private.is_own_active_member(member_id, organisation_id)
  );

-- ---------------------------------------------------------------- helpers
revoke execute on function private.is_own_active_member(uuid, uuid) from PUBLIC, anon, service_role;

-- Haversine distance in metres. Numeric workplace coordinates are cast to
-- double precision by the punch function.
create or replace function private.distance_meters(
  p_lat1 double precision,
  p_lon1 double precision,
  p_lat2 double precision,
  p_lon2 double precision
)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select 12742000::double precision * pg_catalog.asin(
    least(
      1::double precision,
      pg_catalog.sqrt(
        pg_catalog.power(pg_catalog.sin(pg_catalog.radians(p_lat2 - p_lat1) / 2), 2)
        + pg_catalog.cos(pg_catalog.radians(p_lat1))
          * pg_catalog.cos(pg_catalog.radians(p_lat2))
          * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(p_lon2 - p_lon1) / 2), 2)
      )
    )
  );
$$;

revoke execute on function private.distance_meters(
  double precision, double precision, double precision, double precision
) from PUBLIC, anon, authenticated, service_role;

-- Session shape shared by the state and punch responses. Times are formatted
-- in the organisation's timezone so the client does not need an IANA database.
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

create or replace function private.attendance_workplace_json(p_workplace_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select case when w.id is null then null else jsonb_build_object(
    'id', w.id,
    'name', w.name,
    'radius_meters', w.radius_meters
  ) end
  from public.workplaces w
  where w.id = p_workplace_id;
$$;

revoke execute on function private.attendance_workplace_json(uuid)
  from PUBLIC, anon, authenticated, service_role;

create or replace function private.attendance_event_json(p_event_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'event_id', e.id,
    'event_type', e.event_type,
    'method', e.method,
    'validation_result', e.validation_result,
    'rejection_reason', e.rejection_reason,
    'server_time', e.server_time,
    'accuracy_meters', e.accuracy_meters,
    'distance_meters', e.distance_meters,
    'workplace', private.attendance_workplace_json(e.workplace_id),
    'session', private.attendance_session_json(e.session_id)
  )
  from public.attendance_events e
  where e.id = p_event_id;
$$;

revoke execute on function private.attendance_event_json(uuid)
  from PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------- state RPC
create or replace function public.get_attendance_state(p_org uuid)
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
  v_session_id uuid;
  v_session jsonb;
  v_state text;
  v_workplace jsonb;
  v_settings jsonb;
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

  -- An open session wins even if it started on a previous local date.
  select s.id into v_session_id
  from public.attendance_sessions s
  where s.organisation_id = p_org
    and s.member_id = v_member
    and s.check_out_at is null
  order by s.check_in_at desc
  limit 1;

  if v_session_id is null then
    select s.id into v_session_id
    from public.attendance_sessions s
    where s.organisation_id = p_org
      and s.member_id = v_member
      and s.work_date = v_today
    order by s.check_in_at desc
    limit 1;
  end if;

  v_session := private.attendance_session_json(v_session_id);
  v_state := case
    when v_session is null then 'not_started'
    when v_session ->> 'check_out_at' is null then 'checked_in'
    else 'completed'
  end;

  select private.attendance_workplace_json(w.id) into v_workplace
  from public.workplaces w
  where w.organisation_id = p_org
    and w.is_active
  order by w.created_at, w.id
  limit 1;

  select jsonb_build_object(
    'app_punch_enabled', s.app_punch_enabled,
    'qr_punch_enabled', s.qr_punch_enabled,
    'max_accuracy_meters', s.max_accuracy_meters,
    'start_time', pg_catalog.to_char(s.start_time, 'HH24:MI'),
    'grace_minutes', s.grace_minutes,
    'working_days', pg_catalog.to_jsonb(s.working_days)
  ) into v_settings
  from public.attendance_settings s
  where s.organisation_id = p_org;

  if v_settings is null then
    v_settings := jsonb_build_object(
      'app_punch_enabled', true,
      'qr_punch_enabled', false,
      'max_accuracy_meters', 50,
      'start_time', '09:00',
      'grace_minutes', 10,
      'working_days', pg_catalog.to_jsonb('{1,2,3,4,5}'::smallint[])
    );
  end if;

  return jsonb_build_object(
    'server_time', v_now,
    'work_date', v_today,
    'timezone', v_timezone,
    'state', v_state,
    'session', v_session,
    'workplace', v_workplace,
    'settings', v_settings
  );
end;
$$;

revoke execute on function public.get_attendance_state(uuid) from PUBLIC, anon;
grant execute on function public.get_attendance_state(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------- punch RPC
create or replace function public.punch_attendance(
  p_org uuid,
  p_event_type text,
  p_method text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_idempotency_key uuid,
  p_workplace uuid default null,
  p_qr_payload text default null
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
  v_session public.attendance_sessions%rowtype;
  v_workplace public.workplaces%rowtype;
  v_settings public.attendance_settings%rowtype;
  v_existing_event uuid;
  v_event_id uuid;
  v_session_id uuid;
  v_reject text;
  v_distance double precision;
  v_token text;
  v_token_hash text;
  v_method_enabled boolean;
  v_recent_rejections int;
  v_target_workplace_id uuid;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if p_event_type is null or p_event_type not in ('punch_in', 'punch_out') then
    perform private.fail('invalid_event_type');
  end if;

  if p_method is null or p_method not in ('app', 'qr') then
    perform private.fail('invalid_method');
  end if;

  if p_idempotency_key is null then
    perform private.fail('invalid_idempotency_key');
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

  -- Serialise punches per member. This makes duplicate-tap races deterministic:
  -- the second request observes the first request's session and is rejected
  -- as already_checked_in instead of opening a second session.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_member::text, 0)
  );

  select e.id into v_existing_event
  from public.attendance_events e
  where e.member_id = v_member
    and e.idempotency_key = p_idempotency_key;

  if v_existing_event is not null then
    return private.attendance_event_json(v_existing_event);
  end if;

  select o.timezone into v_timezone
  from public.organisations o
  where o.id = p_org;

  if v_timezone is null then
    perform private.fail('org_not_found');
  end if;

  v_today := (v_now at time zone v_timezone)::date;

  select * into v_settings
  from public.attendance_settings s
  where s.organisation_id = p_org;

  if not found then
    perform private.fail('attendance_not_configured');
  end if;

  v_method_enabled := case p_method
    when 'app' then v_settings.app_punch_enabled
    else v_settings.qr_punch_enabled
  end;

  if not v_method_enabled then
    perform private.fail('method_disabled');
  end if;

  select count(*) into v_recent_rejections
  from public.attendance_events e
  where e.member_id = v_member
    and e.validation_result = 'rejected'
    and e.server_time > v_now - interval '60 seconds';

  if v_recent_rejections >= 10 then
    perform private.fail('rate_limited');
  end if;

  -- Resolve and validate the workplace before deciding on location/state.
  if p_method = 'qr' then
    if p_qr_payload is null
       or pg_catalog.left(pg_catalog.btrim(p_qr_payload), 25)
          <> 'attendance:workplace:v1:' then
      v_reject := 'invalid_qr';
    else
      v_token := pg_catalog.replace(
        pg_catalog.btrim(p_qr_payload),
        'attendance:workplace:v1:',
        ''
      );
      v_token := private.normalize_invite_token(v_token);

      if v_token is null or pg_catalog.length(v_token) <> 20 then
        v_reject := 'invalid_qr';
      else
        v_token_hash := private.hash_invite_token(v_token);

        select w.* into v_workplace
        from public.workplace_qr_tokens t
        join public.workplaces w on w.id = t.workplace_id
        where t.organisation_id = p_org
          and t.token_hash = v_token_hash
          and t.revoked_at is null;

        if not found then
          v_reject := 'invalid_qr';
        elsif not v_workplace.is_active then
          v_reject := 'workplace_inactive';
        end if;
      end if;
    end if;
  else
    if p_workplace is not null then
      select w.* into v_workplace
      from public.workplaces w
      where w.id = p_workplace
        and w.organisation_id = p_org;

      if not found then
        v_reject := 'workplace_not_found';
      elsif not v_workplace.is_active then
        v_reject := 'workplace_inactive';
      end if;
    else
      select w.* into v_workplace
      from public.workplaces w
      where w.organisation_id = p_org
        and w.is_active
      order by w.created_at, w.id
      limit 1;

      if not found then
        v_reject := 'no_workplace';
      end if;
    end if;
  end if;

  v_target_workplace_id := v_workplace.id;

  -- Location evidence is validated only when the workplace is known.
  if v_reject is null then
    if p_latitude is null or p_longitude is null
       or p_latitude < -90 or p_latitude > 90
       or p_longitude < -180 or p_longitude > 180
       or p_accuracy_meters is null or p_accuracy_meters < 0 then
      v_reject := 'invalid_location';
    elsif p_accuracy_meters > v_settings.max_accuracy_meters then
      v_reject := 'location_accuracy_too_low';
    else
      v_distance := private.distance_meters(
        p_latitude, p_longitude,
        v_workplace.latitude::double precision,
        v_workplace.longitude::double precision
      );

      if v_distance > v_workplace.radius_meters then
        v_reject := 'outside_geofence';
      end if;
    end if;
  end if;

  -- Attendance state validation (only when the request is otherwise valid).
  if v_reject is null then
    select s.* into v_session
    from public.attendance_sessions s
    where s.organisation_id = p_org
      and s.member_id = v_member
      and s.check_out_at is null
    for update;

    if p_event_type = 'punch_in' then
      if v_session.id is not null then
        v_reject := 'already_checked_in';
      else
        select s.* into v_session
        from public.attendance_sessions s
        where s.organisation_id = p_org
          and s.member_id = v_member
          and s.work_date = v_today;

        if v_session.id is not null then
          v_reject := 'already_completed_today';
        end if;
      end if;
    else
      if v_session.id is null then
        select s.* into v_session
        from public.attendance_sessions s
        where s.organisation_id = p_org
          and s.member_id = v_member
          and s.work_date = v_today;

        if v_session.id is not null then
          v_reject := 'already_completed_today';
        else
          v_reject := 'not_checked_in';
        end if;
      end if;
    end if;
  end if;

  if v_reject is null then
    if p_event_type = 'punch_in' then
      insert into public.attendance_sessions
        (organisation_id, member_id, workplace_id, work_date, check_in_at)
      values
        (p_org, v_member, v_workplace.id, v_today, v_now)
      returning * into v_session;
    else
      update public.attendance_sessions
      set check_out_at = v_now
      where id = v_session.id
      returning * into v_session;
    end if;

    v_session_id := v_session.id;
  end if;

  insert into public.attendance_events
    (organisation_id, member_id, session_id, workplace_id,
     event_type, method, server_time, latitude, longitude,
     accuracy_meters, distance_meters, validation_result,
     rejection_reason, idempotency_key)
  values
    (p_org, v_member, v_session_id, v_target_workplace_id,
     p_event_type, p_method, v_now, p_latitude, p_longitude,
     p_accuracy_meters, v_distance,
     case when v_reject is null then 'accepted' else 'rejected' end,
     v_reject, p_idempotency_key)
  returning id into v_event_id;

  return private.attendance_event_json(v_event_id);
exception
  when unique_violation then
    -- The member lock makes this unlikely. If a concurrent request still wins
    -- (or the same idempotency key arrives twice), fail calmly; the client
    -- refreshes the server state and never shows a false success.
    perform private.fail('punch_conflict');
end;
$$;

revoke execute on function public.punch_attendance(
  uuid, text, text, double precision, double precision, double precision, uuid, uuid, text
) from PUBLIC, anon;
grant execute on function public.punch_attendance(
  uuid, text, text, double precision, double precision, double precision, uuid, uuid, text
) to authenticated, service_role;
