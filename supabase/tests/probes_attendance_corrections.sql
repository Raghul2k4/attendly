-- Behavioural probe for the attendance-correction slice.
--
-- Run against the linked hosted project:
--   npx supabase db query --linked -f supabase/tests/probes_attendance_corrections.sql
--
-- The probe creates a temporary session, exercises every correction rule and
-- then rolls the transaction back, so no attendance record is changed. The
-- ids below belong to the Techloft dev organisation (owner Raghul, employee
-- Suresh, Main Shop); update them for another environment.

begin;

-- ---------------------------------------------------------------- inventory
select tablename, rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public' and tablename = 'attendance_corrections';

select n.nspname as schema, p.proname as function, p.prosecdef as security_definer
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where p.proname in (
  'correct_attendance_checkout',
  'list_attendance_corrections',
  'with_corrections'
)
order by n.nspname, p.proname;

-- The correction table must not be readable by client roles.
select grantee, privilege_type
from information_schema.role_table_grants
where table_name = 'attendance_corrections'
order by grantee, privilege_type;

-- ---------------------------------------------------------------- fixtures
insert into public.attendance_sessions
  (id, organisation_id, member_id, workplace_id, work_date, check_in_at)
values
  ('11111111-2222-3333-4444-555555555555',
   '6fb1482a-77c8-4cb2-897b-fb1a5403e192',
   '6fceccc5-a5db-460c-a349-f38aa157c833',
   '12a87f1a-a1c9-48a9-84a9-6639628e7528',
   '2026-10-16',
   '2026-10-16 09:00:00+05:30');

insert into public.attendance_sessions
  (id, organisation_id, member_id, workplace_id, work_date, check_in_at, check_out_at)
values
  ('99999999-8888-7777-6666-555555555555',
   '6fb1482a-77c8-4cb2-897b-fb1a5403e192',
   '6fceccc5-a5db-460c-a349-f38aa157c833',
   '12a87f1a-a1c9-48a9-84a9-6639628e7528',
   '2026-10-15',
   '2026-10-15 09:00:00+05:30',
   '2026-10-15 17:00:00+05:30');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"027a1f92-2f12-4a8b-a0bd-7d3859339776","role":"authenticated"}',
  true
);

-- ------------------------------------------------------------------ rules
do $verify$
declare
  v_open constant uuid := '11111111-2222-3333-4444-555555555555';
  v_done constant uuid := '99999999-8888-7777-6666-555555555555';
  v_result jsonb;
begin
  -- happy path: close the missed check-out
  v_result := public.correct_attendance_checkout(
    v_open,
    '2026-10-16'::date,
    '18:30'::time,
    'Owner confirmed the employee left at 18:30'
  );
  if v_result ->> 'corrected_check_out_time' <> '18:30' then
    raise exception 'ASSERT: corrected time was %', v_result ->> 'corrected_check_out_time';
  end if;
  if (v_result ->> 'duration_seconds')::int <> 34200 then
    raise exception 'ASSERT: duration was %', v_result ->> 'duration_seconds';
  end if;

  -- the same correction again is rejected
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-16'::date, '18:30'::time, 'Owner confirmed the employee left at 18:30'
    );
    raise exception 'ASSERT: repeated correction was accepted';
  exception when others then
    if sqlerrm not like '%ATT:correction_already_applied%' then raise; end if;
  end;

  -- a reason is required
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-16'::date, '19:00'::time, 'no'
    );
    raise exception 'ASSERT: short reason was accepted';
  exception when others then
    if sqlerrm not like '%ATT:invalid_correction_reason%' then raise; end if;
  end;

  -- the check-out cannot precede the check-in
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-16'::date, '08:00'::time, 'Owner confirmed the employee left at 08:00'
    );
    raise exception 'ASSERT: check-out before check-in was accepted';
  exception when others then
    if sqlerrm not like '%ATT:correction_before_check_in%' then raise; end if;
  end;

  -- the check-out cannot be in the future
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-21'::date, '09:00'::time, 'Owner confirmed the employee left at 09:00'
    );
    raise exception 'ASSERT: future check-out was accepted';
  exception when others then
    if sqlerrm not like '%ATT:correction_in_future%' then raise; end if;
  end;

  -- the check-out must stay on the work date (or the next day for overnight)
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-18'::date, '18:00'::time, 'Owner confirmed the employee left on the 18th'
    );
    raise exception 'ASSERT: out-of-range work date was accepted';
  exception when others then
    if sqlerrm not like '%ATT:correction_outside_work_date%' then raise; end if;
  end;

  -- correcting to the value already stored is rejected
  begin
    perform public.correct_attendance_checkout(
      v_done, '2026-10-15'::date, '17:00'::time, 'Owner confirmed the employee left at 17:00'
    );
    raise exception 'ASSERT: no-op correction was accepted';
  exception when others then
    if sqlerrm not like '%ATT:correction_no_change%' then raise; end if;
  end;

  -- an unknown session is rejected
  begin
    perform public.correct_attendance_checkout(
      '44444444-4444-4444-4444-444444444444'::uuid,
      '2026-10-16'::date,
      '18:30'::time,
      'Owner confirmed the employee left at 18:30'
    );
    raise exception 'ASSERT: unknown session was accepted';
  exception when others then
    if sqlerrm not like '%ATT:attendance_session_not_found%' then raise; end if;
  end;

  -- the employee cannot correct their own record
  perform set_config(
    'request.jwt.claims',
    pg_catalog.json_build_object(
      'sub', 'f9ebabe3-5f0b-4ab1-a186-7a07f9014e54',
      'role', 'authenticated'
    )::text,
    true
  );
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-16'::date, '20:00'::time, 'Employee asked for a later check-out'
    );
    raise exception 'ASSERT: employee correction was accepted';
  exception when others then
    if sqlerrm not like '%ATT:not_org_owner%' then raise; end if;
  end;

  -- another organisation's owner cannot correct it either
  perform set_config(
    'request.jwt.claims',
    pg_catalog.json_build_object(
      'sub', 'daf0be02-342a-4b29-9749-f8a45fb2e574',
      'role', 'authenticated'
    )::text,
    true
  );
  begin
    perform public.correct_attendance_checkout(
      v_open, '2026-10-16'::date, '20:00'::time, 'Owner of another business tried to correct it'
    );
    raise exception 'ASSERT: foreign owner correction was accepted';
  exception when others then
    if sqlerrm not like '%ATT:not_org_owner%' then raise; end if;
  end;

  -- the correction list is owner-only
  begin
    perform public.list_attendance_corrections(
      '6fb1482a-77c8-4cb2-897b-fb1a5403e192'::uuid
    );
    raise exception 'ASSERT: foreign owner listed corrections';
  exception when others then
    if sqlerrm not like '%ATT:not_org_owner%' then raise; end if;
  end;

  -- anonymous callers are rejected
  perform set_config('request.jwt.claims', '{}', true);
  begin
    perform public.list_attendance_corrections(
      '6fb1482a-77c8-4cb2-897b-fb1a5403e192'::uuid
    );
    raise exception 'ASSERT: anonymous correction list was accepted';
  exception when others then
    if sqlerrm not like '%ATT:not_authenticated%' then raise; end if;
  end;

  raise notice 'CORRECTION ASSERTIONS PASSED';
end;
$verify$;

-- -------------------------------------------------------------- audit trail
select set_config(
  'request.jwt.claims',
  '{"sub":"027a1f92-2f12-4a8b-a0bd-7d3859339776","role":"authenticated"}',
  true
);

reset role;

select jsonb_build_object(
  'session', (
    select jsonb_build_object(
      'check_out_at', s.check_out_at,
      'corrected_at', s.corrected_at,
      'corrected_by', s.corrected_by
    )
    from public.attendance_sessions s
    where s.id = '11111111-2222-3333-4444-555555555555'
  ),
  'correction', (
    select jsonb_build_object(
      'original_check_out_at', c.original_check_out_at,
      'corrected_check_out_at', c.corrected_check_out_at,
      'reason', c.reason,
      'actor_user_id', c.actor_user_id
    )
    from public.attendance_corrections c
    where c.session_id = '11111111-2222-3333-4444-555555555555'
  ),
  'audit', (
    select jsonb_build_object(
      'action', a.action,
      'target_type', a.target_type,
      'actor_user_id', a.actor_user_id,
      'reason', a.reason
    )
    from public.audit_logs a
    where a.target_id = '11111111-2222-3333-4444-555555555555'
      and a.action = 'attendance_corrected'
  ),
  'report_entry', (
    select jsonb_build_object(
      'check_in_time', entry ->> 'check_in_time',
      'check_out_time', entry ->> 'check_out_time',
      'is_open', entry ->> 'is_open',
      'is_corrected', entry ->> 'is_corrected',
      'duration_seconds', entry ->> 'duration_seconds'
    )
    from jsonb_array_elements(
      public.get_attendance_report(
        '6fb1482a-77c8-4cb2-897b-fb1a5403e192'::uuid,
        '2026-10-16'::date,
        '2026-10-16'::date,
        null
      ) -> 'sessions'
    ) entry
    where entry ->> 'id' = '11111111-2222-3333-4444-555555555555'
  ),
  'corrections_list', public.list_attendance_corrections(
    '6fb1482a-77c8-4cb2-897b-fb1a5403e192'::uuid
  )
) as verification;

rollback;
