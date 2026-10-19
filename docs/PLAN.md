# Technical Plan — Attendance

Concise Stage 2 plan per AGENTS.md. Living document; update as slices land.

## Current state

- Flutter 3.47.2 (Dart 3.13.2), Android-only, package `com.techloft.attendance`, git repo.
- Supabase CLI 2.121.0 available; **no Docker** → no local Supabase stack. Backend
  verification targets the user's hosted dev project (`supabase link`).
- Auth slice verified on a real device (owner sign-in).
- **Core backend slice live and verified against the hosted project** (see below).
- **Organisation/staff slice implemented in Flutter** (setup gate, create business,
  join with invite token, owner seat/roster view, staff invites, deactivate/
  reactivate). **Verified manually on the CPH2325** against the live backend
  (owner org creation + staff invite flow).
- **Workplaces slice implemented**: backend QR contract live and verified over
  REST; Flutter CRUD with OpenStreetMap map placement, geofence radius slider,
  active toggle and the generate/replace/revoke QR flow. 68 unit/widget tests
  pass; analyzer clean. Device verification pending.

## Architecture decisions

- Feature-first layout: `lib/app` (shell/theme/router), `lib/core` (errors, widgets,
  utils, env), `lib/features/{auth,onboarding,dashboard,...}`.
- State: **Riverpod 3** (`Notifier` + providers). Navigation: **go_router** with
  `refreshListenable` bridge from the auth controller.
- Auth: Supabase email/password. Email confirmation handled honestly
  (`needsEmailVerification` outcome → verification notice, button disabled).
- Error model: single `AppException` + central `mapAuthError` / `mapBackendError`
  with calm, specific microcopy; UI never shows raw SDK text. Backend `ATT:*`
  codes map to fixed copy, unknown codes stay honest.
- Config: `flutter_dotenv` loading committed-placeholder `.env`; publication-safe.
- Organisation feature layout: `lib/features/organisation/{data,domain,presentation}`.
  Screens depend on an `OrganisationRepository` abstraction; widget tests use
  `FakeOrganisationRepository`. Device timezone comes from `flutter_timezone`
  (IANA id), with a searchable curated fallback list.
- Post-auth routing: `/home` is an account gate driven by `myAccountProvider`
  (membership + org + plan). It renders setup choices, owner dashboard, employee
  home or "access paused" — no client-side role flags.
- Android: `minSdk 24`; `INTERNET` plus foreground `ACCESS_COARSE_LOCATION` /
  `ACCESS_FINE_LOCATION` (marker placement now, punch validation later). No
  background location.

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
- `20261019141709_org_select_inactive_members.sql` — deactivated members keep read
  access to the organisation's identity only (name/timezone/plan), so the app can
  show an honest "access paused" state. Workplaces/settings stay restricted to
  invited/active members.
- `20261019150839_workplace_qr_codes.sql` — `workplace_qr_tokens` (id, workplace,
  org, `token_hash` unique, created_by, revoked_at); partial unique index keeps at
  most one live token per workplace; RLS enabled with **no client policies** and
  all table grants revoked, so hashes are unreadable. Owner-checked definer RPCs:
  `generate_workplace_qr(org, workplace)` → full payload `attendance:workplace:v1:
  <20-symbol token>` exactly once (replaces any live token under an advisory lock,
  audited); `revoke_workplace_qr(org, workplace)`; `list_workplace_qr_statuses(org)`
  returns only `(workplace_id, created_at)` for live tokens. A trigger audits
  workplace INSERT/UPDATE (`workplace_created` / `workplace_updated`) because
  those rows are written directly under owner-only RLS.

Error contract: functions raise `ATT:<code>` (P0001). Client maps codes to copy.
Codes: `not_authenticated`, `invalid_org_name`, `unknown_plan`, `unknown_timezone`,
`org_create_failed`, `invalid_employee_name`, `not_org_owner`, `org_not_found`,
`plan_limit_reached`, `invalid_invite_token`, `invite_token_not_found`,
`already_member_of_org`, `already_active_employee`, `member_not_found`,
`owner_status_immutable`, `status_unchanged`, `member_not_claimed`,
`user_active_elsewhere`, `invalid_status`, `plan_change_not_allowed`,
`owner_change_not_allowed`, `protected_field_change_not_allowed`,
`org_reassignment_not_allowed`, `workplace_not_found`, `workplace_inactive`.

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

Workplace QR suite (owner2/owner3/employee accounts, live REST):

- generate → payload format `attendance:workplace:v1:XXXXX-XXXXX-XXXXX-XXXXX`; the
  stored 64-char hash matches SHA-256 of the normalised token (verified).
- a second generate replaces the first (status RPC stays at one live row);
  revoke clears it; status RPC never returns hashes.
- direct `GET workplace_qr_tokens` → 403 for an authenticated owner (revoked
  grants + no policies).
- inactive workplace → `ATT:workplace_inactive`; non-owner and active employee →
  `ATT:not_org_owner`; anonymous → 401.

Advisors remaining (accepted/documented):
- 4× `authenticated_security_definer_function_executable` — intended RPC surface.
- `auth_leaked_password_protection` — not managed by CLI 2.121; enable in dashboard.

## Next slices

3. ~~**Org creation + join UI (Flutter)**~~ — shipped: setup gate, owner create form
   (name + timezone), employee join (token normalisation + mapped errors), owner
   seat/roster dashboard, invite sheet with one-time token + copy, deactivate/
   reactivate with reason-free confirmation (server enforces seat limits and
   guards). Unit/widget tests: `test/unit/*`, `test/widget/{create_organisation,
   join_organisation,owner_home,employee_home,invite_staff_sheet,router_redirect}_*`.
   Verified on the CPH2325 against the live backend.
4. **Workplaces** — shipped: owner-only CRUD under RLS (name, map-placed
   coordinates, 20–500 m radius in the UI, active toggle) plus the QR lifecycle
   above. Tile source is `MapConfig.tileUrlTemplate` (public OSM for pilot only —
   see follow-ups). Employee-visible parts arrive with attendance. Remaining:
   install + manual verification on the test device (map tap, "use my location",
   QR generate/replace/revoke).
5. **Attendance** — server-side punch function (state machine + idempotency +
   geofence/accuracy validation), employee home with live duration, QR scanner flow.
6. **Reports/History** — employee history, owner staff details, daily reports,
   CSV export with formula-injection sanitization.
7. **Corrections & audit** — reason-required adjustments preserving originals.
8. **Release prep** — README/Play checklist, signed bundle config, privacy copy.

## Testing strategy

- Unit: validators, auth + backend error mapping (done, incl. every `ATT:*` code
  used by the UI); next: distance/late/duration/state machines, attendance codes.
- Widget: forms, loading/empty/error, role choice, a11y semantics, button states
  (auth); org create/join validation + navigation, owner roster/seat usage,
  employee home, invite result sheet, workplaces list (empty/list/error), QR card
  (generate/replace/revoke/inactive/error). 68 tests passing. The workplace editor
  is not widget-tested: `flutter_map` would hit the network for tiles, so its map
  behaviour is verified manually on device (validators cover the form inputs).
- Router: welcome→auth→home gate transitions under fake auth stream (done).
- Backend: versioned SQL probes in `supabase/tests/`; behavioural suite executed via
  REST against the linked project (suites A/B/C, this repo's history). No local
  Postgres available, so pgTAP runs are deferred until an environment has Docker.

## Known cleanup / ops follow-ups

- `att-test-*@example.com` throwaway accounts (auth.users) exist in the dev project
  from the verification runs; remove with admin credentials before any demo/export.
- Enable leaked-password protection in the Supabase dashboard (auth settings).
- `db.pooler.default_pool_size` / `max_client_conn` are dashboard-owned and don't
  round-trip through `config push`; differences are expected noise in `config diff`.
- Membership/roster data refreshes on gate load, pull-to-refresh (owner) and after
  mutations; no Realtime subscription yet — an employee deactivated mid-session
  keeps a stale screen until reload (server still rejects all actions).
- The one-time invite token cannot be re-read after creation (hash-only storage).
  A re-issue/rotate flow is required before beta so owners can recover a lost
  token without deleting the member.
- Employees have no pull-to-refresh on their home yet; the paused/active state is
  evaluated when the gate loads.
- Map tiles use the public OpenStreetMap servers (`lib/core/utils/map_config.dart`)
  which are for development/pilot only. Contract a tile provider (or self-host)
  before release; attribution text is already rendered on the map.
- A lost workplace QR cannot be re-displayed (hash-only storage); owners replace
  it, which immediately invalidates the old print. No QR print/share sheet yet —
  the payload is copyable and rendered on screen.

## Major risks / mitigations

- No local Postgres in this environment → behaviour verified over REST against the
  linked hosted project; SQL probes versioned for a future CI with Docker.
- Auth provider rate limits (signup bursts >~15/min/IP) → integration scripts pace
  auth calls; app copy handles 429 honestly.
- Realtime + RLS interplay → not used yet; verify when live attendance lands.
