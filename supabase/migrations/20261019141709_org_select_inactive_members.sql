-- Deactivated employees keep read access to their organisation's identity
-- only. The app shows an honest "access paused" screen with the business
-- name; workplaces and settings stay restricted to invited/active members.

drop policy organisations_select_members on public.organisations;

create policy organisations_select_members on public.organisations
  for select to authenticated
  using ( private.is_member(id, '{invited,active,inactive}') );
