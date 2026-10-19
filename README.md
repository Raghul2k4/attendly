# Attendance

Premium small-business attendance app (owner + employee) — Flutter Android client
over Supabase (Postgres + Auth + RLS). See `AGENTS.md` for the product/engineering
contract and `docs/PLAN.md` for the live status.

## Setup

1. Flutter 3.47+ (`flutter doctor`).
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
npx supabase db push        # applies supabase/migrations/*
npx supabase test db        # pgTAP tests (requires Docker locally)
```

Migrations are version-controlled under `supabase/migrations/` (added in the DB slice).

## Checks

```bash
dart format .             # formatting
flutter analyze           # static analysis
flutter test              # unit + widget tests
flutter build apk --debug # validates the full Android build pipeline
```

## Project layout

```
lib/app        theme tokens, router, app shell
lib/core       errors, env, widgets, utils (no feature coupling)
lib/features   auth · onboarding · dashboard · (staff, workplaces, attendance, reports next)
supabase       config + versioned migrations + SQL tests
test           unit/ · widget/ · support/ (fakes)
```

## Conventions

- Colors/spacing/radii/durations only via `app/theme` tokens.
- User-facing text: calm + specific; errors via `mapAuthError` (never raw SDK text).
- Client never decides attendance validity; server is authoritative (from DB slice).
