# Technical Plan — Attendance

Concise Stage 2 plan per AGENTS.md. Living document; update as slices land.

## Current state

- Flutter 3.47.2 (Dart 3.13.2), Android-only, package `com.techloft.attendance`, git repo.
- Supabase CLI 2.121.0 available; **no Docker** → no local Supabase stack. Backend
  verification targets the user's hosted dev project (`supabase link`).
- Auth slice verified on a real device (owner sign-in).
- **Core backend slice live and verified against the hosted project** (see below).

## Architecture decisions

- Feature-first layout: `lib/app` (shell/theme/router), `lib/core` (errors, widgets,
  utils, env), `lib/features/{auth,onboarding,dashboard,...}`.
- State: **Riverpod 3** (`Notifier` + providers). Navigation: **go_router** with
  `refreshListenable` bridge from the auth controller.
- Auth: Supabase email/password. Email confirmation handled honestly
  (`needsEmailVerification` outcome → verification notice, button disabled).
- Error model: single `AppException` + central `mapAuthError` with calm, specific
  microcopy; UI never shows raw SDK text.
- Config: `flutter_dotenv` loading committed-placeholder `.env`; publication-safe.
- Android: `minSdk 24`, `INTERNET` permission only (foreground location permission
  added in the geofence slice).

## Backend model (live)

Migrations (`supabase/migrations/`):

- `20261019130846_core_schema.sql` — profiles, subscription_plans (free = 15 seats),
  organisations, organisation_members, workplaces, attendance_settings, audit_logs;
  `private.*` helpers with pinned `search_path`; profile trigger + backfill;
  guard triggers (plan/ownership/timezone immutability, no org re-assignment);
  profile-delete trigger frees seats before the FK `SET NULL`.
- `20261019130849_core_rls.sql` — RLS on every table; policy predicates call
  `private.is_active_owner` / `private.is_member` (SECURITY DEFINER, no recursion);
  employees read own membership + shared org facts; owners read org data; member
  writes only through backend functions.
- `20261019130852_org_membership_functions.sql` — SECURITY DEFINER RPCs:
  - `create_organisation(name, timezone, plan)` → uuid (idempotent on retry)
  - `invite_employee(org, full_name)` → (member_id, employee_code, invite_token);
    token returned ONCE, only its SHA-256 is stored
  - `claim_membership(invite_token)` → org uuid; normalisation via one shared helper
  - `set_member_status(org, member, active|inactive)`
  Seat accounting: org row lock first, then count vs plan; claims and reactivations
  re-check under the same lock. One active employee membership per user.
- `20261019134725_advisors_hardening.sql` — pinned search paths; trigger functions
  no longer RPC-callable.

Error contract: functions raise `ATT:<code>` (P0001). Client maps codes to copy.
Codes: `not_authenticated`, `invalid_org_name`, `unknown_plan`, `unknown_timezone`,
`org_create_failed`, `invalid_employee_name`, `not_org_owner`, `org_not_found`,
`plan_limit_reached`, `invalid_invite_token`, `invite_token_not_found`,
`already_member_of_org`, `already_active_employee`, `member_not_found`,
`owner_status_immutable`, `status_unchanged`, `member_not_claimed`,
`user_active_elsewhere`, `invalid_status`, `plan_change_not_allowed`,
`owner_change_not_allowed`, `protected_field_change_not_allowed`,
`org_reassignment_not_allowed`.

Product invariant decided here: **one organisation per owner** (unique index,
idempotent create returns the existing org) and **one active employee membership
per user**. Invitations do not consume seats; invites are also refused when the
plan is already full.

## Verified backend behaviour (live, hosted project)

Executed against the real REST API with throwaway accounts (confirmations
temporarily disabled, then restored):

- org create + idempotent retry; owner sees own org only; cross-org select/audit/
  set-status denied.
- invite → claim happy path; staff code + one-time token formats; unknown,
  malformed, replayed and consumed tokens rejected with mapped codes.
- 15-seat limit: 15 active allowed; 16th claim AND invite at full capacity →
  `plan_limit_reached`; deactivation frees a seat; reactivation at capacity
  blocked; deactivated employee immediately loses org visibility.
- concurrent double-claim of one token: exactly one winner, one
  `invite_token_not_found`, one member row, one audit entry.
- RLS direct-write denials: member INSERT → 403; settings/role UPDATE → 0 rows;
  own profile update applies; employees see zero audit rows.
- guard triggers reject plan/timezone changes; owner row cannot be deactivated;
  anonymous RPC → 401.
- audit trail counts: org created 1 + invites 17 + claims 16 + status change 1.

Advisors remaining (accepted/documented):
- 4× `authenticated_security_definer_function_executable` — intended RPC surface.
- `auth_leaked_password_protection` — not managed by CLI 2.121; enable in dashboard.

## Next slices

3. **Org creation + join UI (Flutter)** — owner onboarding form → `create_organisation`;
   employee join screen → `claim_membership`; seat usage display; repo + tests;
   device verification.
4. **Workplaces** — CRUD + flutter_map geofence UI + QR token generation/revocation.
5. **Attendance** — server-side punch function (state machine + idempotency +
   geofence/accuracy validation), employee home with live duration, QR scanner flow.
6. **Reports/History** — employee history, owner staff details, daily reports,
   CSV export with formula-injection sanitization.
7. **Corrections & audit** — reason-required adjustments preserving originals.
8. **Release prep** — README/Play checklist, signed bundle config, privacy copy.

## Testing strategy

- Unit: validators, error mapping (done); next: distance/late/duration/state
  machines, plan limits, attendance-code mapping.
- Widget: forms, loading/empty/error, role choice, a11y semantics, button states (done
  for auth); next: org form, join flow, punch states.
- Router: welcome→auth→home transitions under fake auth stream (done).
- Backend: versioned SQL probes in `supabase/tests/`; behavioural suite executed via
  REST against the linked project (suites A/B/C, this repo's history). No local
  Postgres available, so pgTAP runs are deferred until an environment has Docker.

## Known cleanup / ops follow-ups

- `att-test-*@example.com` throwaway accounts (auth.users) exist in the dev project
  from the verification runs; remove with admin credentials before any demo/export.
- Enable leaked-password protection in the Supabase dashboard (auth settings).
- `db.pooler.default_pool_size` / `max_client_conn` are dashboard-owned and don't
  round-trip through `config push`; differences are expected noise in `config diff`.

## Major risks / mitigations

- No local Postgres in this environment → behaviour verified over REST against the
  linked hosted project; SQL probes versioned for a future CI with Docker.
- Auth provider rate limits (signup bursts >~15/min/IP) → integration scripts pace
  auth calls; app copy handles 429 honestly.
- Realtime + RLS interplay → not used yet; verify when live attendance lands.
