-- Fix: the QR payload prefix attendance:workplace:v1: is 24 characters,
-- not 25. The original guard compared a 25-character prefix and therefore
-- rejected every valid QR payload. This replaces only the punch function; the
-- original migration stays applied for auditability.

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
       or pg_catalog.left(pg_catalog.btrim(p_qr_payload), 24)
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
