# MASTER PROMPT: PREMIUM SMALL-BUSINESS ATTENDANCE APP

## 1. YOUR ROLE AND MISSION

Act as a senior Flutter engineer, product designer, UX researcher, Supabase/PostgreSQL architect, application security engineer, and QA engineer.

Your mission is to design and build a complete, production-minded Android attendance application for small businesses, ready for preparation and release on the Google Play Store.

Work like an experienced human engineering team. Think through user journeys, data integrity, edge cases, security, visual hierarchy, maintainability, and real-world usability before implementing features.

Do not simply generate code that looks convincing in a screenshot. Build a cohesive, functioning product with real authentication, persistent database records, secure permissions, location validation, reliable attendance calculations, and polished interfaces.

### Working principles

1. Inspect the existing repository before making changes.
2. Preserve working functionality and avoid unnecessary rewrites.
3. Make a clear implementation plan before substantial coding.
4. Implement features end to end, including UI, backend, validation, loading states, error states, and tests.
5. Never claim a feature works until it has been implemented and verified.
6. Do not replace real functionality with hardcoded demo data.
7. Do not leave dead buttons, placeholder screens, fake charts, or simulated success messages in production flows.
8. Use established Flutter and Supabase patterns instead of unnecessary abstractions.
9. Make reasonable decisions independently. Ask questions only when a missing decision materially affects architecture, security, product behavior, or cost.
10. Work incrementally, run the available checks, fix regressions, and maintain a working application throughout development.

---

# 2. PRODUCT OVERVIEW

Build a mobile application that helps small businesses manage employee attendance without expensive or complicated HR software.

The application supports two roles:

- Owner
- Employee

An owner creates an organisation, configures attendance policies and workplace locations, invites employees using permanent staff codes, and monitors attendance.

Employees join an organisation using their staff code and can punch in or out through either the application button or a workplace QR scanner, depending on the methods enabled by their owner.

Every successful punch must pass server-side attendance validation, including authentication, organisation membership, allowed attendance method, location verification, and valid attendance state.

## Product goals

- Extremely easy onboarding for nontechnical business owners.
- Fast attendance recording with minimal taps.
- A premium, calm, professional interface.
- Reliable attendance history and employee statistics.
- Strong separation between organisations.
- Transparent location permissions and privacy.
- Affordable operation for small teams.
- An architecture that can grow into a paid product without requiring a rewrite.

## Target customers

Small shops, restaurants, clinics, gyms, offices, agencies, and other businesses with small teams.

Assume that some users are not technically sophisticated. Use clear language, familiar controls, helpful defaults, and obvious actions.

## Platform and technology

Required stack:

- Flutter and Dart for the Android application.
- Supabase Auth for authentication.
- Supabase PostgreSQL for persistent data.
- PostgreSQL Row Level Security for access control.
- PostgreSQL functions or secured Supabase Edge Functions for sensitive operations.
- Supabase Realtime for live dashboard updates where useful.
- `flutter_map` for maps.
- OpenStreetMap-compatible map tiles from a suitable production provider.
- `geolocator` for foreground location acquisition.
- A maintained Flutter QR/barcode scanning package.
- Riverpod for state management unless the existing repository already uses a sound alternative.
- GoRouter or an equivalent declarative routing solution.
- A maintained charting package only where actual charts improve comprehension.

Use stable, compatible dependency versions. Inspect current package documentation and repository constraints before choosing versions.

Do not add AI features to the attendance workflow. This is a straightforward business application; correctness is more valuable than attaching an LLM to everything.

---

# 3. PRICING AND STAFF LIMITS

The free plan supports up to 15 active employees per organisation.

Paid plans support higher staff limits. Keep paid-plan limits configurable so commercial changes do not require major code changes.

### Requirements

- Enforce limits on the server, not merely in Flutter.
- Count active employee memberships.
- Prevent concurrent employee additions from bypassing the limit.
- Deactivating an employee frees an active seat.
- Preserve historical attendance after employee deactivation.
- Owners can see current usage, such as 8 of 15 seats used.
- When the limit is reached, explain the problem and offer an upgrade path.
- Never silently delete employees or attendance to enforce a plan limit.
- Subscription status must be verified by a trusted backend process.

For the initial release, implement the free plan completely. Build a clean subscription interface and configurable plan model, but do not invent a fake payment flow or claim a paid plan has been activated without a verified billing integration.

---

# 4. ONBOARDING AND AUTHENTICATION

Create a polished onboarding flow.

## Welcome screen

Present the product identity and two clear paths:

- I own a business.
- I am an employee.

The role selection is an onboarding choice, not an authorization mechanism. Permissions must always be enforced by authenticated identity and database policies.

## Authentication

Support secure registration, sign-in, sign-out, and account recovery using an appropriate Supabase Auth flow.

Use phone or email authentication based on the implemented product configuration. Do not present an unconfigured OTP or email verification flow as operational.

Handle:

- Invalid credentials.
- Expired sessions.
- Unverified accounts, where applicable.
- Network failures.
- Password recovery.
- Account deletion and sign-out.
- Loading and retry states.

Persist authentication securely using supported platform storage and Supabase's recommended Flutter configuration.

## Owner onboarding

1. Authenticate.
2. Create an organisation.
3. Enter organisation name and optional logo.
4. Configure timezone, workdays, expected start time, and grace period.
5. Set the staff capacity or select the available plan.
6. Configure the first workplace and geofence.
7. Choose permitted attendance methods.
8. Add the first employee.
9. Display a clear completion screen and take the owner to the dashboard.

Do not force owners to configure every advanced setting before using the application. Provide sensible defaults and allow later editing.

## Employee onboarding

1. Authenticate.
2. Enter the permanent staff code received from the owner.
3. Validate the invitation or membership securely on the server.
4. Complete any required verification.
5. Join the organisation.
6. Load the employee's actual membership, workplace rules, and attendance state.
7. Navigate to the employee dashboard.

A staff code is an identifier or invitation secret, not a password and not a substitute for authentication.

Use high-entropy, revocable invitation credentials. Store secret values as hashes when appropriate. If a readable permanent staff identifier is needed, separate it from the secret used to claim an invitation.

---

# 5. OWNER EXPERIENCE

Build the following functional areas.

## A. Owner dashboard

The dashboard must immediately answer:

- How many employees are active?
- How many are present today?
- Who is currently checked in?
- Who arrived late?
- Which attendance records need attention?

Display useful summary cards and a compact attendance overview.

Include:

- Organisation identity.
- Today's date in the organisation's timezone.
- Active employee count and plan usage.
- Present, late, and unresolved attendance counts.
- A recent attendance activity list.
- Quick actions for Add Staff, Attendance, and Workplaces.
- Loading, empty, and error states.

Every number must come from real database records and documented attendance rules.

Do not count employees as absent before their scheduled workday has ended. If absence and leave rules are not fully implemented, label the number as provisional or omit it.

## B. Staff management

Provide:

- Searchable employee list.
- Employee name and stable staff identifier.
- Active or inactive status.
- Today's attendance status.
- Employee creation and invitation.
- Employee profile and attendance history.
- Employee deactivation with confirmation.
- Seat usage information.
- Useful empty states for new organisations.

When creating an employee:

1. Collect required employee information.
2. Validate it.
3. Create or issue the membership invitation securely.
4. Return the staff identifier or claim code.
5. Let the owner copy or share the invitation.
6. Prevent duplicate active memberships where the product rules prohibit them.

Do not expose invitation secrets to unrelated users.

## C. Employee details

Display:

- Name and employee code.
- Current membership status.
- Today's attendance status.
- Check-in and check-out timestamps.
- Total recorded work duration.
- Monthly attendance summary.
- Late arrivals based on the configured schedule.
- Missing or unresolved sessions.
- Historical records with date filters.

Provide clear navigation between summary and history.

Do not calculate working duration by subtracting arbitrary client-provided values.

## D. Workplace management

Allow owners to:

- Create a workplace.
- Name the workplace.
- Search for or select its location on an OpenStreetMap-based map.
- Confirm a selected marker.
- Configure the allowed geofence radius.
- Edit and deactivate a workplace.
- View configured locations.
- Generate, revoke, and replace the workplace QR code.

Support multiple workplaces in the schema, even if the initial UI focuses on one primary workplace.

Do not claim a map marker's position is accurate unless the user confirms the selection.

## E. Attendance configuration

Allow owners to configure:

- App-button attendance: enabled or disabled.
- QR attendance: enabled or disabled.
- Expected work start time.
- Working days.
- Grace period for late arrival.
- Allowed workplace and geofence radius.

Both punch-in and punch-out must use an enabled method. Owners can select either method or both.

If a method is disabled while an employee is using the app, refresh the effective server-side policy before accepting a punch.

## F. Attendance reports

Provide:

- Date filtering.
- Employee filtering.
- Daily attendance list.
- Employee-specific attendance history.
- Total working hours.
- Late and unresolved session indicators.
- CSV export if implemented.

CSV exports must contain only records the authenticated owner is authorized to access. Sanitize user-controlled values to prevent spreadsheet formula injection.

## G. Attendance corrections

Allow authorized owners to correct legitimate errors, such as a missed check-out.

Requirements:

- Require a reason.
- Record the acting owner.
- Preserve the original event and timestamp.
- Record the adjustment separately.
- Update calculated summaries consistently.
- Prevent unauthorized or contradictory adjustments.

---

# 6. EMPLOYEE EXPERIENCE

## A. Employee dashboard

The home screen should prioritize one task: attendance.

Display:

- Greeting and employee name.
- Organisation and assigned workplace.
- Today's date.
- Current attendance state.
- Check-in time when applicable.
- Elapsed work duration while checked in.
- Available attendance methods.
- Current location-validation status.
- Recent attendance summary.

Use one prominent primary action with context-sensitive labels:

- Punch In.
- Punch Out.
- Attendance Completed.

Do not show both punch-in and punch-out as independently available when the current state permits only one.

## B. App-button punching

When the employee taps the attendance action:

1. Check that the session is authenticated.
2. Obtain fresh foreground location.
3. Check location permission.
4. Validate the reported location accuracy.
5. Fetch or validate the applicable workplace policy.
6. Submit the attendance attempt to the secure backend.
7. Let the backend validate the employee, method, geofence, and attendance state.
8. Display the confirmed server result.
9. Update the dashboard and attendance history.

Use a short loading state and prevent accidental repeated taps.

Do not display success before the server confirms that the transaction succeeded.

## C. QR attendance

The employee can scan the permanent QR displayed at the workplace.

The QR identifies the workplace through a random, revocable identifier. It must not include private employee data, privileged keys, or unrestricted access credentials.

After scanning:

1. Validate the QR with the backend.
2. Acquire fresh location.
3. Check organisation membership.
4. Confirm that QR attendance is enabled.
5. Validate the geofence and attendance state.
6. Record the punch transactionally.
7. Display the confirmed result.

Allow the owner to revoke a compromised QR and print a replacement.

A permanent QR can be photographed and shared. GPS validation, server-side authorization, rate limiting, audit logs, and optional device-integrity checks reduce abuse but cannot guarantee that the scanner is physically beside the printed code.

## D. Attendance history

Provide a clean history screen with:

- Date.
- Check-in time.
- Check-out time.
- Recorded duration.
- Attendance status.
- Relevant correction or exception status.

Include a monthly summary based on actual records.

Handle overnight shifts and organisation timezones correctly if supported. Otherwise, explicitly constrain the MVP to same-day work sessions and prevent unsupported schedules from producing incorrect calculations.

## E. Employee profile

Display:

- Employee name.
- Permanent employee identifier.
- Organisation.
- Membership status.
- Assigned workplace.
- Account settings.
- Sign-out and account management.

Do not reveal another employee's attendance history or private location information.

---

# 7. ATTENDANCE DOMAIN MODEL

Implement an explicit state machine.

The normal flow is:

NOT_CHECKED_IN → CHECKED_IN → COMPLETED

Exceptional states include:

- Open session requiring attention.
- Rejected punch attempt.
- Corrected attendance record.

Rules:

- A user cannot have two simultaneous open sessions for the same organisation unless an explicitly supported multi-session design is introduced.
- Duplicate punch-in requests must not create duplicate sessions.
- Punch-out requires an existing open session.
- A rejected punch must not alter the attendance session.
- Corrections must be auditable.
- Failed network requests must be safely retryable.
- A stale or invalid client state must never override the server's actual attendance state.

Use PostgreSQL transactions, unique constraints, appropriate row locking, and idempotency keys to enforce these rules.

### Time calculations

- Store timestamps as `timestamptz`.
- Use server-generated timestamps.
- Store the organisation's IANA timezone identifier.
- Calculate local attendance dates in the organisation's timezone.
- Define precisely how late arrivals, grace periods, breaks, and missing check-outs are handled.
- Do not silently invent a check-out time.

For the first release, exclude complex payroll and overtime calculations unless they can be implemented and tested correctly.

---

# 8. DATABASE DESIGN

Create version-controlled SQL migrations.

## Required tables

### profiles

- id: UUID referencing the authenticated user.
- full_name.
- optional phone or display information.
- created_at.
- updated_at.

### organisations

- id: UUID.
- name.
- owner_user_id.
- timezone.
- plan_id or equivalent plan reference.
- created_at.
- updated_at.

### organisation_members

- id: UUID.
- organisation_id.
- user_id.
- role: owner or employee.
- employee_code.
- optional staff invitation hash and expiry.
- status: invited, active, or inactive.
- joined_at.
- created_at.
- updated_at.

Use constraints to prevent duplicate memberships and duplicate employee codes within the intended scope.

If invitation codes are one-time claims, store their hash and consumption status separately from the permanent employee identifier.

### workplaces

- id.
- organisation_id.
- name.
- latitude.
- longitude.
- radius_meters.
- is_active.
- created_at.
- updated_at.

Validate coordinate ranges and enforce reasonable radius limits.

### attendance_settings

- organisation_id.
- app_punch_enabled.
- qr_punch_enabled.
- working_days.
- start_time.
- grace_minutes.
- updated_at.

Use appropriate types and constraints rather than storing all settings in an unvalidated JSON blob.

### workplace_qr_tokens

- id.
- workplace_id.
- token_hash.
- created_at.
- revoked_at.
- created_by.

Return the raw random token only through the authorized generation flow. Never expose the stored hash as the QR value.

### attendance_sessions

- id.
- organisation_id.
- member_id.
- workplace_id.
- check_in_at.
- check_out_at.
- status.
- duration_seconds, if cached.
- created_at.
- updated_at.

Enforce valid session states and prevent conflicting open sessions.

### attendance_events

- id.
- session_id, where applicable.
- organisation_id.
- member_id.
- workplace_id.
- event_type.
- method.
- server_time.
- latitude and longitude where justified.
- reported_accuracy_meters.
- validation_result.
- rejection_reason where applicable.
- idempotency_key.

Treat events as append-only through normal application operations.

### audit_logs

- id.
- organisation_id.
- actor_user_id.
- action.
- target_type.
- target_id.
- reason.
- created_at.
- appropriately minimized metadata.

Audit records should not be editable by ordinary owners or employees.

### subscription_entitlements

Add a plan and entitlement model that can enforce active staff limits and later support verified paid subscriptions.

Keep subscription-provider identifiers and webhook state separate from client-controlled data.

## Database engineering requirements

- Add foreign keys and appropriate indexes.
- Use UUID primary keys.
- Apply unique constraints for stable identifiers and membership rules.
- Enforce referential integrity.
- Use transactions for multi-record attendance changes.
- Write migration and rollback procedures where feasible.
- Avoid unnecessary duplication of computed values.
- Define a retention and deletion policy for attendance evidence and location data.
- Ensure employee deactivation does not cascade-delete attendance history.

---

# 9. SECURITY AND ROW LEVEL SECURITY

Security must be implemented before real customer data is added.

Enable RLS on every exposed table and create explicit policies for each operation.

## Access requirements

Employees can:

- Read their own profile.
- Read their own membership and authorised organisation details.
- Read their own attendance history.
- Submit an attendance attempt through the authorized server operation.
- Update only permitted personal profile fields.

Employees cannot:

- Change their own role to owner.
- Modify attendance timestamps directly.
- Change geofence rules.
- Access other employees' private records.
- Read staff invitation secrets or privileged QR-token data.
- Bypass plan limits.

Owners can:

- Manage the organisation they own.
- Manage memberships within that organisation.
- Configure its workplaces and attendance policies.
- Read authorised staff attendance records.
- Request and audit legitimate attendance corrections.

Owners cannot:

- Access unrelated organisations.
- Assign themselves ownership of arbitrary organisations.
- Modify protected fields through unrestricted client updates.
- Read server secrets or unrelated subscription data.

## Sensitive operations

Use narrowly scoped PostgreSQL functions or secured Edge Functions for:

- Organisation creation.
- Staff invitation and claim.
- Employee addition and deactivation.
- Workplace QR generation and validation.
- Attendance punch processing.
- Attendance corrections.
- Subscription entitlement changes.

For `SECURITY DEFINER` functions, set a safe search path, fully qualify database objects, validate the caller explicitly, and restrict execute privileges. Never assume that a function is secure merely because it runs on the server.

Never place Supabase service-role or secret keys in Flutter, Git, screenshots, logs, or public configuration.

## Threat model

Test against:

- Cross-organisation data access.
- Forged employee identifiers.
- Unauthorized owner actions.
- Staff-code guessing and replay.
- QR copying and revocation.
- Duplicate requests and race conditions.
- Stale sessions.
- Modified client timestamps.
- GPS spoofing and implausible location accuracy.
- Rate-limit abuse.
- CSV formula injection.
- Privileged key exposure.

Treat client GPS as evidence with limitations, not proof of physical presence.

---

# 10. GEOLOCATION AND MAP IMPLEMENTATION

Use `flutter_map` with OpenStreetMap-derived map tiles.

## Map requirements

- Display appropriate map attribution.
- Allow workplace search or manual marker selection.
- Show the chosen location and geofence radius.
- Allow the owner to confirm the location.
- Support marker repositioning and radius changes.
- Handle tile loading errors gracefully.
- Select a production tile provider whose terms and usage limits suit the application.

Do not assume the public OpenStreetMap tile servers provide unlimited commercial capacity.

## Location requirements

Use foreground location access only for the MVP.

When attendance is attempted:

1. Check whether location services are enabled.
2. Check permission state.
3. Request permission when appropriate.
4. Obtain a fresh location reading.
5. Validate reported accuracy.
6. Submit the reading to the server.
7. Compare it against the configured workplace geofence.
8. Record only the location evidence necessary for attendance verification.

Make the accuracy threshold and radius configurable through server-side policy where appropriate.

Initial defaults for pilot testing:

- Geofence radius: 100 metres.
- Maximum acceptable reported accuracy: 50 metres.

These are configurable starting points, not universal truths. Test them at real workplaces and tune the settings to GPS behavior.

Do not collect continuous location in the background. Clearly explain location use before permission is requested.

---

# 11. PREMIUM UI/UX DESIGN SYSTEM

The application must feel like a carefully designed commercial product, not a generic admin dashboard generated from a template.

The design should be modern, restrained, polished, and practical. Prioritize hierarchy, legibility, spacing, useful feedback, and interaction quality over decorative effects.

## Design direction

Create a premium productivity interface with:

- Warm off-white or soft neutral backgrounds.
- Deep navy or charcoal primary text.
- A confident emerald or teal accent for successful attendance actions.
- Muted slate secondary text.
- Restrained amber for warnings.
- Clear red error states.
- White or neutral elevated surfaces.
- Subtle borders and soft, controlled shadows.
- Rounded cards and buttons with consistent geometry.

Use color consistently and test contrast in both light and dark environments if dark mode is implemented.

Do not use gradients, glassmorphism, glowing borders, excessive blur, or neon colors merely to make the interface look expensive. Every effect must serve a purpose.

### Design tokens

Create centralized theme tokens for:

- Primary, secondary, accent, success, warning, error, background, surface, border, and text colors.
- Typography scale and font weights.
- Spacing scale.
- Corner radii.
- Elevation and shadow levels.
- Icon sizes.
- Animation durations.
- Minimum touch target sizes.

Use a coherent spacing system based on multiples of four. Prefer consistent page gutters and card padding.

Use a clean, highly legible typeface, such as a well-supported Inter-style font, with appropriate fallbacks.

Avoid scattering literal colors, arbitrary padding, and duplicated text styles throughout widgets.

## Layout rules

- Use safe areas and respect system bars.
- Design for common Android phone sizes first.
- Support smaller screens without overflow.
- Use scrolling where content exceeds available space.
- Keep primary actions reachable.
- Maintain readable contrast and comfortable text sizes.
- Avoid excessive card nesting.
- Align related content consistently.
- Use icons with meaningful labels where an icon alone could be ambiguous.
- Provide visible keyboard focus and accessibility semantics where relevant.
- Respect system font scaling.
- Use responsive layouts for different device widths.

## Animation rules

Use purposeful motion:

- Short fade or slide transitions between major screens.
- Small scale or opacity feedback on button interaction.
- A clear success transition after confirmed attendance.
- Subtle loading indicators.
- Smooth expansion for secondary details.
- Gentle state transitions in attendance summaries.

Use motion sparingly, keep it responsive, and respect reduced-motion preferences where available.

Never delay an important action with an unnecessary animation.

## Component library

Build reusable, themed components for:

- Primary and secondary buttons.
- Form fields.
- Search inputs.
- Status chips.
- Staff list items.
- Summary cards.
- Empty states.
- Loading skeletons.
- Error and retry panels.
- Confirmation dialogs.
- Bottom sheets.
- Date filters.
- Attendance timeline items.
- Location status indicators.
- QR scanning overlays.
- Snackbars and transient feedback.

Components must have clear states, consistent spacing, and proper accessibility behavior.

---

# 12. SCREEN-BY-SCREEN UI SPECIFICATION

## A. Splash screen

- Display the product logo and wordmark.
- Use a restrained background.
- Show a brief, subtle entrance animation.
- Route according to authentication and onboarding state.
- Do not leave the user staring at an artificial loading screen.

## B. Welcome and role selection

- Present a clear product value proposition.
- Offer two visually balanced role options.
- Use simple iconography and short explanations.
- Provide obvious sign-in and registration paths.
- Do not ask for location permission here.

## C. Authentication screens

- Use clear labels and properly configured keyboard types.
- Show inline validation errors.
- Preserve user input where safe.
- Display loading and retry states.
- Avoid hiding error messages in generic snackbars.

## D. Owner dashboard

Suggested layout:

1. Header with organisation name and profile access.
2. Current date and attendance summary.
3. Compact metric cards.
4. Attendance activity list.
5. Quick actions.
6. Bottom navigation.

Use a clear visual hierarchy. The most important information should be visible without making the owner scroll through decorative content.

## E. Staff list

- Search field at the top.
- Clear active/inactive status.
- Employee names and stable staff identifiers.
- Today's attendance state.
- Add employee action.
- Filters where useful.
- Empty state with a direct Add Staff action.

Avoid displaying too many tiny metrics on every row.

## F. Employee details

- Strong employee identity header.
- Today's attendance status.
- Check-in and check-out timeline.
- Summary statistics.
- Attendance history.
- Correction and exception indicators.

Use actual database records and meaningful date filters.

## G. Workplace map

- Large usable map area.
- Clear selected marker.
- Visible geofence circle.
- Search or manual positioning.
- Radius control.
- Location confirmation action.
- Tile and location error states.

Make it obvious which location is being configured and what radius applies.

## H. Attendance configuration

- Distinct controls for app-button and QR methods.
- Workday schedule.
- Start time and grace period.
- Workplace association.
- Save state and validation feedback.

Clearly explain when a change takes effect.

## I. Employee home

This screen is the heart of the product.

Suggested hierarchy:

1. Organisation and date.
2. A prominent attendance status.
3. Current session duration, if checked in.
4. One primary Punch In or Punch Out action.
5. Available method selector or QR scan action.
6. Location validation status.
7. Recent attendance summary.
8. Access to history and profile.

The interface should make it difficult to misunderstand whether the employee is currently checked in.

Do not show a successful attendance state until the backend confirms the transaction.

## J. QR scanner

- Clearly explain scanning instructions.
- Request camera permission contextually.
- Use a visible scan frame.
- Provide torch control where supported.
- Handle invalid, revoked, or unreadable QR codes.
- Handle denied camera permission.
- Show location validation separately from QR validation.
- Return to the appropriate screen after success or failure.

## K. Attendance history

- Clear date grouping.
- Check-in and check-out times.
- Work duration.
- Status labels.
- Useful filters.
- Empty and error states.
- Correct timezone presentation.

## L. Profile and settings

- Account details.
- Organisation or membership information.
- Notification preferences if supported.
- Privacy information.
- Sign-out.
- Account deletion or the applicable supported account-removal process.

Do not expose settings that are not implemented.

---

# 13. HUMAN-CENTERED INTERACTION QUALITY

Make the product feel designed by someone who has watched actual people use business software.

For every screen, answer:

- What is the user's main goal?
- What should they notice first?
- What is the next logical action?
- What happens when the action fails?
- What if they have never used the feature before?
- What if the network disappears?
- What if they tap twice?
- What if they deny permission?
- How do they recover without losing their work?

## Microcopy

Use direct, calm, useful language.

Good examples:

- "You're checked in."
- "Location accuracy is too low. Try again outdoors."
- "You're outside the permitted workplace area."
- "QR code is no longer valid. Ask your owner for a replacement."
- "You already have an open attendance session."
- "No attendance records for this date."
- "Your changes couldn't be saved. Try again."

Avoid vague messages such as "Something went wrong" when a more specific explanation is available.

## Loading and failure behavior

Every asynchronous operation must have:

- Loading state.
- Success state.
- Empty state where applicable.
- Recoverable error state.
- Appropriate retry behavior.
- Protection against duplicate submissions.

Do not disable the entire application during a small network request.

## Offline behavior

The first release does not need fully offline attendance.

When offline:

- Clearly indicate that attendance cannot currently be verified.
- Do not pretend an unconfirmed punch succeeded.
- Do not silently queue a punch and later record it with a misleading timestamp.
- Preserve safe form input where appropriate.
- Retry idempotent requests safely.
- Refresh the actual server state after reconnecting.

---

# 14. FLUTTER PROJECT ARCHITECTURE

Prefer feature-first organization with clear separation between presentation, domain logic, and data access.

Suggested structure:

lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    errors/
    location/
    permissions/
    networking/
    widgets/
    utils/
  features/
    auth/
      data/
      domain/
      presentation/
    onboarding/
    organisations/
    staff/
    workplaces/
    attendance/
    reports/
    settings/
  shared/
    models/
    repositories/
  main.dart

Use the exact structure that best fits the existing repository. Do not create empty folders or abstractions merely to imitate this diagram.

## Engineering conventions

- Use null safety correctly.
- Prefer immutable models where appropriate.
- Keep widgets focused and reasonably small.
- Separate data access from UI.
- Centralize error mapping.
- Use typed domain models rather than unstructured dynamic maps throughout the application.
- Avoid giant widgets and giant service classes.
- Avoid unnecessary global state.
- Avoid duplicate repository implementations.
- Use dependency injection where it improves testability.
- Keep secrets out of source control.
- Document genuinely non-obvious security or business logic.
- Follow Dart and Flutter conventions.
- Run formatter, analyzer, and tests regularly.

Create a concise README with setup instructions, environment variables, migrations, test commands, and build steps.

---

# 15. SUPABASE ARCHITECTURE

Supabase should be the authoritative source of business and attendance data.

## Client-side responsibilities

Flutter can:

- Authenticate the user.
- Read authorized data through RLS.
- Display records.
- Acquire foreground location.
- Scan QR codes.
- Submit attendance attempts.
- Subscribe to permitted realtime updates.

Flutter must not:

- Decide conclusively whether a punch is valid.
- Write arbitrary authoritative timestamps.
- Change protected roles or subscription entitlements.
- Bypass staff limits.
- Read another organisation's private records.
- Hold privileged backend secrets.

## Server-side responsibilities

Use appropriately secured database functions or Edge Functions to:

- Create organisations and establish ownership.
- Issue and claim staff invitations.
- Manage employee membership.
- Generate and revoke workplace QR identifiers.
- Validate workplace QR codes.
- Process attendance transactions.
- Apply owner-authorized attendance corrections.
- Enforce plan entitlements.
- Record audit events.

Use transactional SQL where atomicity and concurrency control are required.

## Realtime

Subscribe only to records the authenticated user is authorized to receive.

When an event arrives, refresh the relevant query or update state consistently. Handle duplicate events, reconnects, and stale local state.

Realtime is not a substitute for database authorization or transaction safety.

## Environment setup

Separate development and production environments where feasible.

Use environment configuration for public project URLs and publishable keys. Store service secrets only in the appropriate server-side secret manager.

Never commit actual production secrets.

---

# 16. TESTING REQUIREMENTS

Write tests as part of implementation, not as a final cosmetic activity.

## Unit tests

Test:

- Attendance state transitions.
- Working duration calculations.
- Timezone and workday calculations.
- Late-arrival calculations.
- Staff limit logic.
- Input validation.
- Geofence distance calculations.
- Error mapping.
- Entitlement decisions.

## Widget tests

Test:

- Role selection.
- Form validation.
- Loading states.
- Empty states.
- Attendance button state.
- QR error feedback.
- Responsive layouts.
- Accessibility semantics for primary controls.

## Backend tests

Test:

- RLS isolation between organisations.
- Employee access restrictions.
- Owner permissions.
- Staff invitation security.
- Concurrent staff additions.
- Concurrent punch requests.
- Duplicate idempotency keys.
- Invalid or revoked QR codes.
- Invalid geofence coordinates.
- Attendance corrections and audit trails.
- Subscription entitlement enforcement.

## Integration tests

Test realistic end-to-end flows:

1. Create an owner account.
2. Create an organisation.
3. Configure a workplace.
4. Add an employee.
5. Claim the employee invitation.
6. Complete a valid punch-in.
7. Complete a valid punch-out.
8. Confirm correct duration and history.
9. Verify that another organisation cannot access those records.

Also test weak GPS, permission denial, network loss, expired sessions, revoked QR codes, app restart, and repeated button taps.

Do not claim a test passed unless it was actually executed.

---

# 17. PERFORMANCE, RELIABILITY, AND MAINTENANCE

- Paginate large attendance histories.
- Index frequently queried membership, workplace, and attendance columns.
- Avoid N+1 queries when displaying staff summaries.
- Calculate statistics efficiently.
- Avoid unnecessary full-page refreshes.
- Use stable keys for repeated widgets.
- Dispose of controllers and subscriptions properly.
- Handle expired authentication sessions.
- Log server errors without exposing sensitive data.
- Use automated database backups and periodically test restoration.
- Keep dependencies maintained and review security advisories.
- Avoid loading a large map or chart before it is needed.

For the initial free tier, optimize for organisations with up to 15 active employees while preserving a schema and query design that can scale beyond that limit.

---

# 18. GOOGLE PLAY RELEASE REQUIREMENTS

Prepare the app for a real public release.

Include:

- Correct Android package identifier.
- App name and launcher icon.
- Version and build-number management.
- Signed Android App Bundle.
- Current supported target SDK according to Google Play's policy at release time.
- Privacy policy hosted at a stable public URL.
- Accurate Data safety declarations.
- Permission explanations and contextual requests.
- Account deletion support and required Play Store disclosures.
- Screenshots and store listing.
- Testing instructions for reviewers.
- Crash reporting and basic operational monitoring, if configured.
- Production Supabase configuration.
- Verified database migrations and security policies.

Review the current Google Play policies when preparing the release. Do not hardcode assumptions about target SDK requirements, billing policies, testing tracks, or account-specific release eligibility.

If the app supports account creation, implement the account deletion process and applicable in-app and external deletion requirements.

Do not publish until security, data access, location behavior, and the main attendance workflow have been tested.

---

# 19. DEVELOPMENT WORKFLOW

Follow this sequence.

## Stage 1: Repository inspection

Inspect:

- Existing project structure.
- Flutter and Dart versions.
- Dependencies.
- Current screens.
- Existing Supabase configuration.
- Database migrations.
- Existing authentication and routing.
- Tests and known issues.

Identify what can be reused and what needs to be built.

Do not overwrite existing work blindly.

## Stage 2: Implementation plan

Produce a short technical plan covering:

- Architecture decisions.
- Required screens.
- Database migrations.
- RLS policies.
- Backend functions.
- Dependency choices.
- Testing strategy.
- Major risks.

Then begin implementation rather than stopping after producing a plan.

## Stage 3: Design system

Implement the theme, design tokens, reusable components, typography, spacing, navigation, and screen states.

Verify the design on a real or emulated Android screen size.

## Stage 4: Vertical feature implementation

Implement in this order:

1. Authentication and role-aware onboarding.
2. Organisation creation.
3. Employee invitations and staff management.
4. Database security and plan limits.
5. Workplace management and geofencing.
6. App-button attendance.
7. Permanent workplace QR attendance.
8. Employee history and owner reports.
9. Attendance corrections and audit trail.
10. Release preparation.

Keep the app compiling and testable after each meaningful increment.

## Stage 5: Verification

After each feature:

- Run Dart formatting.
- Run Flutter analysis.
- Run relevant unit and widget tests.
- Run backend and database tests where available.
- Fix failures before building further on top.
- Inspect the actual UI.
- Verify real data persistence.
- Test permission and failure states.

## Stage 6: Final report

At the end, report:

- Features implemented.
- Files and migrations added.
- Tests actually executed and their results.
- Security controls implemented.
- Environment setup still required.
- Known limitations.
- Any manual steps required before production deployment.

Distinguish implemented features from planned features. Never claim production readiness merely because the app compiles.

---

# 20. FINAL ACCEPTANCE CRITERIA

The MVP is complete only when:

1. An owner can register and create an organisation.
2. An owner can add employees and issue permanent staff identifiers.
3. An employee can securely join the correct organisation.
4. The free plan's 15-active-staff limit is enforced on the server.
5. Owners can configure attendance methods and workplace geofences.
6. Employees can punch in and out using every enabled method.
7. Invalid location, identity, QR, and attendance states are rejected.
8. Successful attendance records persist correctly across app restarts.
9. Owners can view accurate employee attendance and working duration.
10. Employees can view only their authorized attendance history.
11. Organisation data remains isolated under tested RLS policies.
12. Attendance corrections preserve an audit trail.
13. Loading, empty, error, and permission-denied states are polished.
14. The interface is responsive, accessible, and visually consistent.
15. Automated tests cover important business rules and security boundaries.
16. Release documentation and Play Store compliance requirements are prepared.

# YOUR FIRST TASK

Start by inspecting the existing repository.

Do not immediately generate every screen or rewrite the whole application.

First, summarize the current project state and identify the next smallest vertical slice that can be implemented, tested, and verified end to end.

Then proceed with the implementation. Use sound engineering judgment, maintain the premium design direction throughout, and keep the product functional at every stage.