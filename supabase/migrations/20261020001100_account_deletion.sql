-- Account deletion (Google Play account-deletion requirement).
--
-- Two different outcomes, because the data has two different owners:
--
--   * An owner deletes their business. The organisation, its workplaces, QR
--     tokens, settings, memberships and every attendance session/event,
--     correction and audit row are removed. This is irreversible and the UI
--     makes the consequence explicit before calling this function.
--
--   * An employee deletes their sign-in identity. The existing
--     private.handle_profile_deleted trigger deactivates their seat (so the
--     owner recovers it) and organisation_members.user_id becomes null. The
--     employer keeps the attendance records as business records; the employee's
--     name stays on the member row for those records, while the profile and
--     auth identity are deleted.
--
-- Deleting auth.users cascades to public.profiles; the app then clears its
-- local session. The function is SECURITY DEFINER because auth.users is not
-- writable by clients, so the caller is validated explicitly and the search
-- path is empty with every object fully qualified.

create or replace function public.delete_my_account(p_confirm text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
begin
  if v_uid is null then
    perform private.fail('not_authenticated');
  end if;

  -- Deliberate typed confirmation: this action cannot be undone. The client
  -- cannot rely on its own dialog alone, and a stale/replayed request must not
  -- delete an account by accident.
  if p_confirm is distinct from 'DELETE' then
    perform private.fail('delete_confirm_required');
  end if;

  -- Owner path. Delete in dependency order instead of relying on cascades:
  -- attendance_sessions references members and workplaces with ON DELETE
  -- RESTRICT, so a single cascade could fail depending on delete order.
  for v_org in
    select o.id
    from public.organisations o
    where o.owner_user_id = v_uid
  loop
    delete from public.attendance_corrections c
    where c.organisation_id = v_org;
    delete from public.attendance_events e
    where e.organisation_id = v_org;
    delete from public.attendance_sessions s
    where s.organisation_id = v_org;
    delete from public.workplace_qr_tokens q
    where q.organisation_id = v_org;
    delete from public.audit_logs a
    where a.organisation_id = v_org;
    delete from public.organisation_members m
    where m.organisation_id = v_org;
    delete from public.workplaces w
    where w.organisation_id = v_org;
    delete from public.attendance_settings st
    where st.organisation_id = v_org;
    delete from public.organisations o
    where o.id = v_org;
  end loop;

  -- Employee path: leave a note in each employer's audit trail before the
  -- profile row is removed. attendance_sessions.member_id stays valid because
  -- the member row is kept (deactivated by the profile trigger).
  insert into public.audit_logs
    (organisation_id, actor_user_id, action, target_type, target_id, reason)
  select m.organisation_id, v_uid, 'account_deleted', 'member', m.id, null
  from public.organisation_members m
  where m.user_id = v_uid
    and m.role = 'employee';

  delete from auth.users u
  where u.id = v_uid;

  if not found then
    perform private.fail('account_not_found');
  end if;
end;
$$;

revoke execute on function public.delete_my_account(text)
  from public, anon, authenticated;
grant execute on function public.delete_my_account(text) to authenticated;
