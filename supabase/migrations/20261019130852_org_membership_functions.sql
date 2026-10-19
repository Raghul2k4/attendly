-- Attendance — organisation membership backend functions.
-- SECURITY DEFINER with empty search_path, fully-qualified objects and
-- in-body caller validation. Direct table writes stay closed by RLS.
--
-- Seat accounting invariant: every path that turns a membership into an
-- ACTIVE employee acquires a row lock on the organisation FIRST (consistent
-- lock order across invite / claim / status-change, so no deadlock cycles),
-- then counts active seats against the plan before writing.

-- ---------------------------------------------------------------- create org

create or replace function public.create_organisation(
  p_name text,
  p_timezone text default 'UTC',
  p_plan_id text default 'free'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_caller uuid := (select auth.uid());
  v_plan text;
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  p_name := btrim(coalesce(p_name, ''));
  if p_name = '' or length(p_name) > 80 then
    perform private.fail('invalid_org_name');
  end if;

  select plan_id into v_plan
  from public.subscription_plans
  where plan_id = p_plan_id and is_active;
  if v_plan is null then
    perform private.fail('unknown_plan');
  end if;

  -- Validate IANA timezone before it can corrupt later date math.
  if p_timezone is null or not exists (
    select 1 from pg_catalog.pg_timezone_names where name = p_timezone
  ) then
    perform private.fail('unknown_timezone');
  end if;

  begin
    insert into public.organisations (name, owner_user_id, timezone, plan_id)
    values (p_name, v_caller, p_timezone, v_plan)
    returning id into v_org;
  exception
    when unique_violation then
      -- The only unique constraint here is organisations_owner_unique, so a
      -- violation means the caller already owns an organisation: treat a
      -- timed-out retry as idempotent and return it.
      select id into v_org
      from public.organisations
      where owner_user_id = v_caller;
      if v_org is null then
        perform private.fail('org_create_failed');
      end if;
      return v_org;
  end;

  insert into public.attendance_settings (organisation_id)
  values (v_org);

  insert into public.organisation_members
    (organisation_id, user_id, role, status, full_name, joined_at)
  values (
    v_org, v_caller, 'owner', 'active',
    coalesce(
      (select p.full_name from public.profiles p where p.id = v_caller),
      'Owner'
    ),
    now()
  );

  perform private.write_audit(v_org, 'organisation_created', 'organisation', v_org, null);
  return v_org;
end;
$$;

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

  if v_limit is null or v_seats >= v_limit then
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

  -- Normalise: shared helper (upper-cases, strips dashes/whitespace) — the
  -- same function applied to the token before its hash was stored at invite.
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

  -- Re-read the member under the lock: it may have been claimed, revoked or
  -- deactivated while we waited.
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

  if v_limit is null or v_seats >= v_limit then
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

  -- Seat accounting step 1: org row lock, consistent with invite/claim.
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
    -- Deactivating the only owner would strand the organisation; ownership
    -- ends only with the owner's account (cascade).
    perform private.fail('owner_status_immutable');
  end if;

  if v_current = p_status then
    perform private.fail('status_unchanged');
  end if;

  if p_status = 'active' then
    if v_target_user is null then
      -- Seat accounting applies only to bound members; an unbound inactive
      -- row (post account deletion) cannot be re-activated.
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

    if v_limit is null or v_seats >= v_limit then
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

-- ---------------------------------------------------------------- grants
revoke execute on function public.create_organisation(text, text, text) from PUBLIC, anon;
revoke execute on function public.invite_employee(uuid, text) from PUBLIC, anon;
revoke execute on function public.claim_membership(text) from PUBLIC, anon;
revoke execute on function public.set_member_status(uuid, uuid, text) from PUBLIC, anon;
grant execute on function public.create_organisation(text, text, text) to authenticated, service_role;
grant execute on function public.invite_employee(uuid, text) to authenticated, service_role;
grant execute on function public.claim_membership(text) to authenticated, service_role;
grant execute on function public.set_member_status(uuid, uuid, text) to authenticated, service_role;
