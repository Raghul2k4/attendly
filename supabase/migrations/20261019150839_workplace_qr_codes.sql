-- Attendance — workplace QR codes.
-- Only a SHA-256 hash of the random token is stored; the raw payload is
-- returned exactly once by generate_workplace_qr (same discipline as staff
-- invite tokens). Scanning/validation arrives with the attendance slice.
--
-- Payload format: attendance:workplace:v1:<token> where <token> is 20
-- symbols from the app's ambiguity-free alphabet. Validation must normalise
-- the token (case/dashes) before hashing — see private.normalize_invite_token.

create table public.workplace_qr_tokens (
  id              uuid primary key default gen_random_uuid(),
  workplace_id    uuid not null references public.workplaces (id) on delete cascade,
  organisation_id uuid not null references public.organisations (id) on delete cascade,
  token_hash      text not null unique,
  created_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  revoked_at      timestamptz
);

create index workplace_qr_tokens_workplace_idx
  on public.workplace_qr_tokens (workplace_id);
create index workplace_qr_tokens_org_active_idx
  on public.workplace_qr_tokens (organisation_id)
  where revoked_at is null;

-- At most one live QR per workplace; generating a replacement revokes the
-- previous token in the same transaction.
create unique index workplace_qr_tokens_one_active_idx
  on public.workplace_qr_tokens (workplace_id)
  where revoked_at is null;

-- No client policies at all: hashes are never readable from the client and
-- writes only happen through the owner-checked definer functions below.
alter table public.workplace_qr_tokens enable row level security;
revoke all on table public.workplace_qr_tokens from anon, authenticated;

-- ---------------------------------------------------------------- audit
-- Workplaces are written directly through RLS (owner-only), so audit the
-- changes from a trigger to keep the trail complete regardless of client.
create or replace function private.audit_workplace_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit(
      new.organisation_id, 'workplace_created', 'workplace', new.id, null
    );
  elsif tg_op = 'UPDATE' then
    perform private.write_audit(
      new.organisation_id, 'workplace_updated', 'workplace', new.id, null
    );
  end if;
  return new;
end;
$$;

revoke execute on function private.audit_workplace_changes()
  from public, anon, authenticated, service_role;

create trigger workplaces_audit_changes
  after insert or update on public.workplaces
  for each row execute function private.audit_workplace_changes();

-- ---------------------------------------------------------------- QR generate
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
    (workplace_id, organisation_id, token_hash, created_by)
  values (
    p_workplace,
    p_org,
    private.hash_invite_token(private.normalize_invite_token(v_token)),
    v_caller
  );

  perform private.write_audit(
    p_org, 'workplace_qr_generated', 'workplace', p_workplace, null
  );

  return 'attendance:workplace:v1:' || v_token;
end;
$$;

-- ---------------------------------------------------------------- QR revoke
create or replace function public.revoke_workplace_qr(
  p_org uuid,
  p_workplace uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_revoked int;
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

  update public.workplace_qr_tokens
  set revoked_at = now()
  where workplace_id = p_workplace and revoked_at is null;

  get diagnostics v_revoked = row_count;
  if v_revoked > 0 then
    perform private.write_audit(
      p_org, 'workplace_qr_revoked', 'workplace', p_workplace, null
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------- QR status
-- Returns only metadata; hashes never leave the server. Used by the owner UI
-- to show whether a printable QR exists.
create or replace function public.list_workplace_qr_statuses(p_org uuid)
returns table (workplace_id uuid, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
begin
  if v_caller is null then
    perform private.fail('not_authenticated');
  end if;

  if not private.is_active_owner(p_org) then
    perform private.fail('not_org_owner');
  end if;

  return query
  select t.workplace_id, t.created_at
  from public.workplace_qr_tokens t
  where t.organisation_id = p_org and t.revoked_at is null
  order by t.created_at desc;
end;
$$;

revoke execute on function public.generate_workplace_qr(uuid, uuid)
  from public, anon;
revoke execute on function public.revoke_workplace_qr(uuid, uuid)
  from public, anon;
revoke execute on function public.list_workplace_qr_statuses(uuid)
  from public, anon;

grant execute on function public.generate_workplace_qr(uuid, uuid) to authenticated;
grant execute on function public.revoke_workplace_qr(uuid, uuid) to authenticated;
grant execute on function public.list_workplace_qr_statuses(uuid) to authenticated;
