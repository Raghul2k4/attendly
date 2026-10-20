-- Attendance is unusable when every punch method is disabled. The owner UI
-- already prevents this; enforce it on the table so a direct API write cannot
-- strand employees without a valid punch path.
--
-- Existing rows are checked during migration. If a project somehow already has
-- an organisation with both methods off, the migration fails loudly rather than
-- silently turning a method back on.

alter table public.attendance_settings
  add constraint attendance_settings_method_required
  check (app_punch_enabled or qr_punch_enabled);
