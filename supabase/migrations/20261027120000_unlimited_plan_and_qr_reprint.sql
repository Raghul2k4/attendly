-- Attendly — unlimited staff + re-openable workplace QR codes.
--
-- 1) The free plan is now genuinely free: `max_active_employees` is nullable,
--    and NULL means "no limit". Seat accounting stays in place for future paid
--    plans (a non-null limit is still enforced under the organisation row
--    lock), but no current plan sets one. Existing attendance is untouched.
--
-- 2) Owners can print the workplace QR as many times as they like. The first
--    QR schema stored only the SHA-256 of the token, so the raw payload existed
--    in the owner's screen memory for one visit and was unrecoverable after
--    that — a refresh, a new app launch or a second owner lost the code. The
--    token is now stored alongside its hash and can be read back through
--    `get_workplace_qr`, which is owner-only. Direct table access stays
--    revoked, so the value never leaves the server through a table select.
--
-- Security note: the QR token is a semi-public workplace identifier by design
-- (it is printed and hung on a wall), and a scan still requires an
-- authenticated employee, an enabled QR method and a geofence-valid location.
-- Storing it enables reprinting; it does not grant access on its own.

-- ---------------------------------------------------------------- 1. plans
alter table public.subscription_plans
  alter column max_active_employees drop not null,
  drop constraint subscription_plans_max_active_employees_check;

alter table public.subscription_plans
  add constraint subscription_plans_max_active_employees_check
  check (max_active_employees is null or max_active_employees > 0);

-- The free plan is unlimited. Paid plan rows may still set a positive limit.
update public.subscription_plans
set max_active_employees = null
where plan_id = 'free';

-- ---------------------------------------------------------------- invite
create or replace function public.invite_employee(
  p_org uuid,
  p_full_name text
)
returns table (member_id uuid, employee_code text, invite_token text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_org_exists uuid;
  v_seats int;
  v_limit int;
  v_code text;
  v_token text;
  v_member uuid;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  p_full_name := btrim(coalesce(p_full_name, ''));
  if p_full_name = '' or length(p_full_name) > 80 then
    perform private.fail('invalid_employee_name');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  -- Seat accounting step 1: serialise on the organisation row (held until
  -- commit) so invites, claims and reactivations cannot interleave.
  select id into v_org_exists
  from public.organisations
  where id = p_org
  for update;
  if v_org_exists is null then
    perform private.fail('org_not_found');
  end if;

  -- Re-validate ownership under the lock (no TOCTOU against status change).
  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  select count(*) into v_seats
  from public.organisation_members m
  where m.organisation_id = p_org
    and m.role = 'employee'
    and m.status = 'active';

  select p.max_active_employees into v_limit
  from public.organisations o
  join public.subscription_plans p on p.plan_id = o.plan_id
  where o.id = p_org;

  -- NULL limit = unlimited (the free plan). A null row still fails: every
  -- organisation has a plan, so v_limit is null only when the plan row is
  -- missing, which must not silently grant seats.
  if not exists (
    select 1
    from public.organisations o
    join public.subscription_plans p on p.plan_id = o.plan_id
    where o.id = p_org
  ) then
    perform private.fail('plan_limit_reached');
  end if;

  if v_limit is not null and v_seats >= v_limit then
    perform private.fail('plan_limit_reached');
  end if;
  -- Invited-but-unclaimed rows do not consume seats by design; each claim
  -- re-checks the limit under the same org lock before activating, so
  -- over-inviting cannot overshoot ACTIVE staff.

  -- Collision-free code within this organisation.
  loop
    v_code := private.generate_staff_code();
    exit when not exists (
      select 1 from public.organisation_members m
      where m.organisation_id = p_org and m.employee_code = v_code
    );
  end loop;

  v_token := private.generate_invite_token();

  insert into public.organisation_members
    (organisation_id, role, status, full_name, employee_code, claim_token_hash)
  values (p_org, 'employee', 'invited', p_full_name, v_code,
          private.hash_invite_token(private.normalize_invite_token(v_token)))
  returning id into v_member;

  perform private.write_audit(p_org, 'employee_invited', 'membership', v_member, null);

  -- Raw token is handed to the owner exactly once; only its hash is stored.
  return query select v_member, v_code, v_token;
end;
$$;

-- ---------------------------------------------------------------- claim
create or replace function public.claim_membership(p_invite_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member public.organisation_members;
  v_caller uuid := (select auth.uid());
  v_norm text;
  v_org uuid;
  v_org_exists uuid;
  v_seats int;
  v_limit int;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  v_norm := private.normalize_invite_token(p_invite_token);
  if v_norm !~ '^[A-HJ-KM-NP-Z2-9]{20}$' then
    perform private.fail('invalid_invite_token');
  end if;

  select m.* into v_member
  from public.organisation_members m
  where m.claim_token_hash = private.hash_invite_token(v_norm)
    and m.status = 'invited'
    and m.user_id is null;
  if not found then
    perform private.fail('invite_token_not_found');
  end if;
  v_org := v_member.organisation_id;

  -- Seat accounting step 1: org row lock, consistent with invite/status.
  select id into v_org_exists
  from public.organisations
  where id = v_org
  for update;

  select * into v_member
  from public.organisation_members m
  where m.id = v_member.id
    and m.status = 'invited'
    and m.user_id is null
  for update;
  if not found then
    perform private.fail('invite_token_not_found');
  end if;

  if exists (
    select 1 from public.organisation_members m
    where m.user_id = v_caller
      and m.organisation_id = v_org
      and m.id <> v_member.id
  ) then
    perform private.fail('already_member_of_org');
  end if;

  if exists (
    select 1 from public.organisation_members m
    where m.user_id = v_caller
      and m.role = 'employee'
      and m.status = 'active'
  ) then
    perform private.fail('already_active_employee');
  end if;

  select count(*) into v_seats
  from public.organisation_members m
  where m.organisation_id = v_org
    and m.role = 'employee'
    and m.status = 'active';

  select p.max_active_employees into v_limit
  from public.organisations o
  join public.subscription_plans p on p.plan_id = o.plan_id
  where o.id = v_org;

  select o.id into v_org_exists
  from public.organisations o
  join public.subscription_plans p on p.plan_id = o.plan_id
  where o.id = v_org;
  if v_org_exists is null then
    perform private.fail('org_not_found');
  end if;

  if v_limit is not null and v_seats >= v_limit then
    perform private.fail('plan_limit_reached');
  end if;

  begin
    update public.organisation_members
    set user_id = v_caller, status = 'active', joined_at = now()
    where id = v_member.id;
  exception
    when unique_violation then
      perform private.fail('already_active_employee');
  end;

  perform private.write_audit(v_org, 'membership_claimed', 'membership', v_member.id, null);

  return v_org;
end;
$$;

-- ---------------------------------------------------------------- status
create or replace function public.set_member_status(
  p_org uuid,
  p_member uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current text;
  v_role text;
  v_target_user uuid;
  v_org_exists uuid;
  v_seats int;
  v_limit int;
  v_caller uuid := (select auth.uid());
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if p_status not in ('active', 'inactive') then
    perform private.fail('invalid_status');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  select id into v_org_exists
  from public.organisations
  where id = p_org
  for update;
  if v_org_exists is null then
    perform private.fail('org_not_found');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  select status::text, role::text, user_id
  into v_current, v_role, v_target_user
  from public.organisation_members
  where id = p_member and organisation_id = p_org
  for update;

  if not found then
    perform private.fail('member_not_found');
  end if;

  if v_role = 'owner' then
    perform private.fail('owner_status_immutable');
  end if;

  if v_current = p_status then
    perform private.fail('status_unchanged');
  end if;

  if p_status = 'active' then
    if v_target_user is null then
      perform private.fail('member_not_claimed');
    end if;

    if exists (
      select 1 from public.organisation_members m
      where m.user_id = v_target_user
        and m.id <> p_member
        and m.role = 'employee'
        and m.status = 'active'
    ) then
      perform private.fail('user_active_elsewhere');
    end if;

    select count(*) into v_seats
    from public.organisation_members m
    where m.organisation_id = p_org
      and m.role = 'employee'
      and m.status = 'active';

    select p.max_active_employees into v_limit
    from public.organisations o
    join public.subscription_plans p on p.plan_id = o.plan_id
    where o.id = p_org;

    if v_limit is not null and v_seats >= v_limit then
      perform private.fail('plan_limit_reached');
    end if;
  end if;

  begin
    update public.organisation_members
    set status = p_status::public.org_member_status
    where id = p_member;
  exception
    when unique_violation then
      perform private.fail('user_active_elsewhere');
  end;

  perform private.write_audit(p_org, 'member_status_changed', 'membership', p_member, p_status);
end;
$$;

-- ---------------------------------------------------------------- 2. QR token
alter table public.workplace_qr_tokens
  add column token text;

-- Legacy live tokens were created before the raw value was kept; they cannot
-- be reprinted. get_workplace_qr reports qr_not_recoverable so the owner UI
-- can offer a replacement instead of pretending the code is printable.

create or replace function public.generate_workplace_qr(
  p_org uuid,
  p_workplace uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_active boolean;
  v_token text;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  select w.is_active into v_active
  from public.workplaces w
  where w.id = p_workplace and w.organisation_id = p_org;

  if v_active is null then
    perform private.fail('workplace_not_found');
  end if;
  if not v_active then
    perform private.fail('workplace_inactive');
  end if;

  -- Serialise replacement per workplace so concurrent generate calls cannot
  -- race the partial unique index.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_workplace::text, 0)
  );

  v_token := private.generate_invite_token();

  update public.workplace_qr_tokens
  set revoked_at = now()
  where workplace_id = p_workplace and revoked_at is null;

  insert into public.workplace_qr_tokens
    (workplace_id, organisation_id, token_hash, token, created_by)
  values (
    p_workplace,
    p_org,
    private.hash_invite_token(private.normalize_invite_token(v_token)),
    private.normalize_invite_token(v_token),
    v_caller
  );

  perform private.write_audit(
    p_org, 'workplace_qr_generated', 'workplace', p_workplace, null
  );

  return 'attendance:workplace:v1:' || v_token;
end;
$$;

-- Read back the live payload so the printed poster can be downloaded again.
-- Only the owner may call it, and only a currently valid token is returned.
create or replace function public.get_workplace_qr(
  p_org uuid,
  p_workplace uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_token text;
  v_has_live boolean;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  if not exists (
    select 1 from public.workplaces w
    where w.id = p_workplace and w.organisation_id = p_org
  ) then
    perform private.fail('workplace_not_found');
  end if;

  select t.token, true into v_token, v_has_live
  from public.workplace_qr_tokens t
  where t.workplace_id = p_workplace
    and t.organisation_id = p_org
    and t.revoked_at is null;

  if not found then
    perform private.fail('qr_not_generated');
  end if;
  if v_token is null then
    perform private.fail('qr_not_recoverable');
  end if;

  return 'attendance:workplace:v1:' || v_token;
end;
$$;

revoke execute on function public.get_workplace_qr(uuid, uuid) from public, anon;
grant execute on function public.get_workplace_qr(uuid, uuid) to authenticated;
