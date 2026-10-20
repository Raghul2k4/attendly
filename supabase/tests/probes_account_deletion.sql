-- Behavioural probe for public.delete_my_account. Everything runs inside one
-- transaction and is rolled back, so no real account or record is touched.
--
--   npx supabase db query --linked -f supabase/tests/probes_account_deletion.sql

begin;

-- ---------------------------------------------------------------- fixtures
-- Owner account: owns a business with one employee member, one session, one
-- correction, one audit row and one QR token.
insert into auth.users (
  id, aud, role, email, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values (
  'aaaaaaaa-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
  'probe-owner@example.invalid', now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Probe Owner"}'::jsonb
);

insert into public.organisations (id, name, owner_user_id, timezone, plan_id)
values (
  'bbbbbbbb-0000-4000-8000-000000000001', 'Probe Business',
  'aaaaaaaa-0000-4000-8000-000000000001', 'Asia/Kolkata', 'free'
);

insert into public.organisation_members
  (id, organisation_id, user_id, role, status, full_name, joined_at)
values
  ('cccccccc-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000001',
   'aaaaaaaa-0000-4000-8000-000000000001', 'owner', 'active', 'Probe Owner', now()),
  ('cccccccc-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-000000000001',
   null, 'employee', 'inactive', 'Probe Employee', null);

update public.organisation_members
set employee_code = 'PROB-0001'
where id = 'cccccccc-0000-4000-8000-000000000002';

insert into public.workplaces
  (id, organisation_id, name, latitude, longitude, radius_meters)
values (
  'dddddddd-0000-4000-8000-000000000001',
  'bbbbbbbb-0000-4000-8000-000000000001', 'Probe Shop',
  13.082700, 80.270700, 100
);

insert into public.attendance_settings (organisation_id)
values ('bbbbbbbb-0000-4000-8000-000000000001');

insert into public.workplace_qr_tokens
  (organisation_id, workplace_id, token_hash)
values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  'dddddddd-0000-4000-8000-000000000001', 'probe-token-hash'
);

insert into public.attendance_sessions
  (id, organisation_id, member_id, workplace_id, work_date, check_in_at, check_out_at)
values (
  'eeeeeeee-0000-4000-8000-000000000001',
  'bbbbbbbb-0000-4000-8000-000000000001',
  'cccccccc-0000-4000-8000-000000000002',
  'dddddddd-0000-4000-8000-000000000001',
  '2026-10-01', '2026-10-01 09:00:00+05:30', '2026-10-01 18:00:00+05:30'
);

insert into public.attendance_events
  (organisation_id, member_id, session_id, workplace_id, event_type, method,
   server_time, validation_result, idempotency_key)
values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  'cccccccc-0000-4000-8000-000000000002',
  'eeeeeeee-0000-4000-8000-000000000001',
  'dddddddd-0000-4000-8000-000000000001',
  'punch_out', 'app', '2026-10-01 18:00:00+05:30', 'accepted',
  'ffffffff-0000-4000-8000-000000000001'
);

insert into public.attendance_corrections
  (organisation_id, session_id, member_id, original_check_out_at,
   corrected_check_out_at, reason, actor_user_id)
values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  'eeeeeeee-0000-4000-8000-000000000001',
  'cccccccc-0000-4000-8000-000000000002',
  '2026-10-01 18:00:00+05:30', '2026-10-01 18:30:00+05:30',
  'Probe correction for cascade coverage',
  'aaaaaaaa-0000-4000-8000-000000000001'
);

insert into public.audit_logs
  (organisation_id, actor_user_id, action, target_type, target_id)
values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  'aaaaaaaa-0000-4000-8000-000000000001', 'probe_action', 'session',
  'eeeeeeee-0000-4000-8000-000000000001'
);

-- ------------------------------------------------------- owner deletion path
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select public.delete_my_account('DELETE');

do $$
begin
  if exists (select 1 from auth.users where id = 'aaaaaaaa-0000-4000-8000-000000000001') then
    raise exception 'owner auth user survived deletion';
  end if;
  if exists (select 1 from public.organisations where id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'organisation survived deletion';
  end if;
  if exists (select 1 from public.attendance_sessions where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'attendance session survived deletion';
  end if;
  if exists (select 1 from public.attendance_events where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'attendance event survived deletion';
  end if;
  if exists (select 1 from public.attendance_corrections where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'correction survived deletion';
  end if;
  if exists (select 1 from public.audit_logs where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'audit log survived deletion';
  end if;
  if exists (select 1 from public.workplace_qr_tokens where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000001') then
    raise exception 'QR token survived deletion';
  end if;
end;
$$;

-- ---------------------------------------------------- employee deletion path
insert into auth.users (
  id, aud, role, email, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values (
  'aaaaaaaa-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
  'probe-employee@example.invalid', now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Probe Employee"}'::jsonb
);

insert into auth.users (
  id, aud, role, email, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values (
  'aaaaaaaa-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
  'probe-other-owner@example.invalid', now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Probe Other Owner"}'::jsonb
);

-- The workplace audit trigger attributes the row to auth.uid(), so switch the
-- claims to the employer before creating their fixtures (the deleted owner's
-- profile no longer exists).
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

insert into public.organisations (id, name, owner_user_id, timezone, plan_id)
values (
  'bbbbbbbb-0000-4000-8000-000000000002', 'Probe Employer',
  'aaaaaaaa-0000-4000-8000-000000000003', 'Asia/Kolkata', 'free'
);

insert into public.organisation_members
  (id, organisation_id, user_id, role, status, full_name, employee_code, joined_at)
values (
  'cccccccc-0000-4000-8000-000000000003', 'bbbbbbbb-0000-4000-8000-000000000002',
  'aaaaaaaa-0000-4000-8000-000000000002', 'employee', 'active',
  'Probe Employee', 'PROB-0002', now()
);

insert into public.workplaces
  (id, organisation_id, name, latitude, longitude, radius_meters)
values (
  'dddddddd-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-000000000002',
  'Probe Shop 2', 13.082700, 80.270700, 100
);

insert into public.attendance_sessions
  (id, organisation_id, member_id, workplace_id, work_date, check_in_at, check_out_at)
values (
  'eeeeeeee-0000-4000-8000-000000000002',
  'bbbbbbbb-0000-4000-8000-000000000002',
  'cccccccc-0000-4000-8000-000000000003',
  'dddddddd-0000-4000-8000-000000000002',
  '2026-10-02', '2026-10-02 09:00:00+05:30', '2026-10-02 17:00:00+05:30'
);

insert into public.attendance_events
  (organisation_id, member_id, session_id, workplace_id, event_type, method,
   server_time, validation_result, idempotency_key)
values (
  'bbbbbbbb-0000-4000-8000-000000000002',
  'cccccccc-0000-4000-8000-000000000003',
  'eeeeeeee-0000-4000-8000-000000000002',
  'dddddddd-0000-4000-8000-000000000002',
  'punch_in', 'app', '2026-10-02 09:00:00+05:30', 'accepted',
  'ffffffff-0000-4000-8000-000000000002'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

select public.delete_my_account('DELETE');

do $$
begin
  if exists (select 1 from auth.users where id = 'aaaaaaaa-0000-4000-8000-000000000002') then
    raise exception 'employee auth user survived deletion';
  end if;
  if exists (select 1 from public.profiles where id = 'aaaaaaaa-0000-4000-8000-000000000002') then
    raise exception 'employee profile survived deletion';
  end if;
  if not exists (
    select 1
    from public.organisation_members
    where id = 'cccccccc-0000-4000-8000-000000000003'
      and user_id is null
      and status = 'inactive'
  ) then
    raise exception 'employee membership was not deactivated and detached';
  end if;
  if not exists (
    select 1 from public.attendance_sessions
    where id = 'eeeeeeee-0000-4000-8000-000000000002'
  ) then
    raise exception 'employer attendance session was deleted';
  end if;
  if not exists (
    select 1 from public.attendance_events
    where idempotency_key = 'ffffffff-0000-4000-8000-000000000002'
  ) then
    raise exception 'employer attendance event was deleted';
  end if;
  if not exists (
    select 1 from public.audit_logs
    where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000002'
      and action = 'account_deleted'
  ) then
    raise exception 'employee deletion was not audited';
  end if;
  if not exists (
    select 1 from auth.users where id = 'aaaaaaaa-0000-4000-8000-000000000003'
  ) then
    raise exception 'unrelated owner account was deleted';
  end if;
end;
$$;

-- -------------------------------------------------------- confirmation guard
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

do $$
begin
  begin
    perform public.delete_my_account('delete');
    raise exception 'lower-case confirmation was accepted';
  exception
    when sqlstate 'P0001' then
      if sqlerrm not like 'ATT:delete_confirm_required%' then
        raise;
      end if;
  end;
end;
$$;

do $$
declare
  v_sessions int;
  v_events int;
  v_audits int;
begin
  select count(*) into v_sessions from public.attendance_sessions
  where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000002';
  select count(*) into v_events from public.attendance_events
  where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000002';
  select count(*) into v_audits from public.audit_logs
  where organisation_id = 'bbbbbbbb-0000-4000-8000-000000000002';
  raise notice 'probe ok: owner cascade, employee retention (sessions=%, events=%, audits=%)',
    v_sessions, v_events, v_audits;
end;
$$;

rollback;
