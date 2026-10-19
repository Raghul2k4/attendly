# Technical Plan — Attendance

Concise Stage 2 plan per AGENTS.md. Living document; update as slices land.

## Current state

- Flutter 3.47.2 (Dart 3.13.2), Android-only, package `com.techloft.attendance`, git repo.
- Supabase CLI 2.121.0 available; **no Docker** → no local Supabase stack. Backend
  verification targets the user's hosted dev project (`supabase link`).
- Environment: hosted Supabase project exists; credentials supplied later via `.env` /
  `supabase login`. `.env` committed with **placeholder values only** + explicit
  ConfigMissing bootstrap screen so the app never fakes a working backend.

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

## Dependency choices (resolved by `pub add`)

supabase_flutter ^2.18.3 · flutter_riverpod ^3.4.3 · go_router ^18.1.0 ·
flutter_dotenv ^6.0.1 · intl ^0.20.3 · dev: mocktail ^1.0.5.
Bundled Inter variable font (no runtime fetch). Planned later: flutter_map + tile
provider, geolocator, a maintained QR scanner (mobile_scanner or equivalent),
possible charting package only if it clarifies data.

## Slice roadmap (each slice compiles + passes `analyze`/`test`)

1. **Auth slice (this)** — theme tokens/components, bootstrap/config, email/password
   auth end-to-end client-side, tests. ✅ implemented
2. **DB slice** — migrations 0001 (profiles/organisations/members/workplaces/
   settings/QR tokens/sessions/events/audit/entitlements), RLS + SECURITY DEFINER
   functions (org create, invitation issue/claim, membership mgmt), plan-limit
   enforcement (15 active employees), organisation creation + employee join UI.
3. **Workplaces** — CRUD + flutter_map geofence UI + QR token generation/revocation.
4. **Attendance** — server-side punch function (state machine + idempotency +
   geofence/accuracy validation), employee home with live duration, QR scanner flow.
5. **Reports/History** — employee history, owner staff details, daily reports,
   CSV export with formula-injection sanitization.
6. **Corrections & audit** — reason-required adjustments preserving originals.
7. **Release prep** — README/Play checklist, signed bundle config, privacy copy.

## Testing strategy

- Unit: validators, error mapping (done); next: distance/late/duration/state
  machines, plan limits.
- Widget: forms, loading/empty/error, role choice, a11y semantics, button states (done
  for auth); next: punch states, chips, skeletons.
- Router: welcome→auth→home transitions under fake auth stream (done).
- Backend: SQL/RLS tests via `supabase test db`/pgTAP when linked project or Docker is
  available; scripts versioned in `supabase/tests`.

## Major risks / mitigations

- No local Postgres in this environment → backend verification waits for linked
  hosted project; frontend verified independently.
- Auth provider rate limits in dev → surface hashed copies, honest 429 copy.
- Realtime + RLS interplay → verify policies with WALRUS/RLS probes at DB-slice time.
