# Attendance

Premium small-business attendance app (owner + employee) — Flutter Android client
over Supabase (Postgres + Auth + RLS). See `AGENTS.md` for the product/engineering
contract, `docs/PLAN.md` for the live status and `docs/PLAY_RELEASE.md` for the
Play Store checklist.

## Setup

1. Flutter 3.47+ (`flutter doctor`), Android SDK, a device or emulator.
2. Copy `.env.example` → `.env` (a placeholder `.env` is committed) and fill:
   - `SUPABASE_URL` — your project URL
   - `SUPABASE_ANON_KEY` — publishable anon key (never service-role!)
3. Run:

```bash
flutter pub get
flutter run            # debug run on device/emulator
```

Until real Supabase values are provided, the app deliberately boots into a
"Configure Supabase" screen instead of pretending the backend works.

## Backend (Supabase)

```bash
npx supabase login
npx supabase link --project-ref <ref>
npx supabase db push                # applies supabase/migrations/*
npx supabase db advisors --linked   # security/performance lint on the linked project
npx supabase db query --linked --file supabase/tests/probes_core_schema.sql
npx supabase config diff            # review before config push (never blank-push)
npx supabase test db                # pgTAP tests (requires Docker locally)
```

Migrations are version-controlled under `supabase/migrations/`; read-only SQL probes
live in `supabase/tests/`. Behavioural checks against the live API were run as REST
suites (documented in `docs/PLAN.md`); scripts that create throwaway accounts must
pace auth calls (signup rate limit).

Auth emails must point at a URL that works on a phone; `supabase/config.toml` holds
the deep-link `site_url` (`com.techloft.attendance://login-callback`) and is aligned
with the live project — always `config diff` first, and expect two dashboard-owned
pooler settings to show as permanent diffs.

### Sensitive operations

Attendance validity, staff limits, QR generation and account deletion are decided
by `SECURITY DEFINER` Postgres functions, not by the client:

- `punch_attendance(...)` — method, membership, state and geofence validation,
  idempotency, rate limiting, per-member locking.
- `invite_employee` / `claim_membership` / `set_member_status` — seat accounting
  under an organisation row lock.
- `generate_workplace_qr` / `revoke_workplace_qr` — raw tokens returned once,
  hashes stored.
- `correct_attendance_checkout` / `list_attendance_corrections` — owner-only,
  reason required, original value and audit row preserved.
- `delete_my_account(confirm)` — owner deletes the business and its records;
  employee removes the sign-in identity, frees the seat and leaves the
  employer's attendance records intact.

## Checks

```bash
dart format .             # formatting
flutter analyze           # static analysis
flutter test              # unit + widget tests
flutter build apk --debug # validates the full Android build pipeline
```

## Release builds

Release signing reads `android/key.properties` (gitignored); the upload key lives
at `android/upload-keystore.jks` (also gitignored). **Back both up** — losing them
after publishing requires a Play upload-key reset. When `key.properties` is
missing, release builds fail with a clear message instead of shipping an unsigned
or debug-signed bundle.

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

The version comes from `pubspec.yaml` (`version: 1.0.0+1`): the name before `+`
is the user-visible version, the number after it is the `versionCode` and must
increase for every Play upload. Tag submitted builds (`v1.0.0`). The target SDK is
supplied by Flutter and was verified as 36 in the merged release manifest; re-check
Play's current requirement at submission time.

Account deletion is available in-app under **Account → Delete account**; the
web-facing copy for Play's deletion URL is `docs/legal/ACCOUNT_DELETION.md`, and
the privacy policy (in-app copy plus hostable text) is
`docs/legal/PRIVACY_POLICY.md`. Both need a monitored publisher contact and a
public HTTPS URL before publishing.

## Tester build

Share `dist/attendance-1.0.0-arm64-v8a.apk` (built locally, gitignored) with
testers. The two-phone walkthrough — owner on one phone, employee on the other —
is in [`docs/TESTER_GUIDE.md`](docs/TESTER_GUIDE.md). It covers onboarding, the
geofence, QR scanning, corrections, permissions, offline behaviour and account
deletion, with a pass/fail checklist and a bug-report template.

Release builds run R8. A keep-rule file
(`android/app/proguard-rules.pro`) protects the Kotlin classes that Pigeon's JNI
bridge resolves by name; without it the release APK hangs on the splash screen
while debug builds work. Rebuild and smoke-test a release APK after changing
plugins.

## Brand assets

`assets/app_icon_source.png` is the single source of truth for the app identity.
`tool/generate_icons.ps1` derives the legacy launcher PNGs, the adaptive
foreground/monochrome layers, the round icons and `docs/store/play-icon-512.png`
from it; `tool/generate_feature_graphic.ps1` writes the store feature graphic.
The splash screen (`BrandMark`) renders the full illustration, while the
launcher icon uses its centre figure so it stays legible through Android's icon
mask. Re-run both scripts after changing the artwork.

## Project layout

```
lib/app        theme tokens, router, app shell
lib/core       errors, env, location, widgets, utils (no feature coupling)
lib/features   auth · onboarding · organisation · workplaces · attendance · reports
supabase       config + versioned migrations + SQL tests
test           unit/ · widget/ · support/ (fakes)
tool           reproducible icon / feature-graphic generators
docs           plan, Play release guide, legal copy, store assets
```

## Conventions

- Colors/spacing/radii/durations only via `app/theme` tokens.
- User-facing text: calm + specific; errors via `mapAuthError` / `mapBackendError`
  (never raw SDK text).
- Client never decides attendance validity; the server is authoritative.
- No feature is shown as working until the server confirms it; loading, empty,
  error and retry states are required for every async path.
