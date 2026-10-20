# Privacy policy — Attendance

> **Before publishing:** this text must be hosted at a stable public HTTPS URL
> (for example `https://your-domain/privacy`) and that URL must be entered in
> Play Console → App content → Privacy policy. Replace the publisher contact
> placeholder at the end. The in-app copy
> (`lib/features/auth/presentation/privacy_policy_screen.dart`) must be kept in
> sync with this document.

**Last updated: 20 October 2026**

Attendance is a workplace attendance app for small businesses. The business that
invites you (your employer) decides which workplaces, schedules and attendance
methods apply to you. The app is operated by your employer using software
provided by the app publisher.

## What we store

**Account.** Your name, email address and a securely hashed password. The app
never stores your password in readable form.

**Work.** Your business name, timezone, workplaces (name, map coordinates and
geofence radius), working days, start time, grace period and attendance-method
settings.

**Attendance.** Check-in and check-out times, the method used, the workplace,
the location reported by your phone at the moment of the punch (latitude,
longitude, reported accuracy and distance from the workplace), and whether the
punch was accepted or rejected.

**Corrections.** When an owner changes a check-out time, the previous value, the
new value, the reason and the owner who made the change are kept.

## Location

Location is used only in the foreground: when you punch in or out, or when an
owner places a workplace on the map. The app does not track you in the
background and does not collect location between punches. A punch is rejected
when the reported accuracy is too low or the position is outside the workplace
geofence configured by your employer.

## Why we use it

To sign you in, record attendance, apply your employer's schedules and grace
period, verify that a punch happened at a workplace, show attendance history and
reports, and keep an audit trail of owner corrections. We do not use this data
for advertising, and the app contains no advertising or analytics SDKs.

## Who can see it

You can see your own profile and attendance history. The owner of your business
can see the attendance records of their team. Other businesses cannot access
your records — access is enforced in the database, not only in the app. Data is
hosted by Supabase on our behalf. Map tiles are requested from a map tile
provider, which receives your IP address as part of that request but never your
location.

## How long it is kept

Attendance records are kept for as long as your employer needs them as business
records. If an employee deletes their account, the sign-in identity and profile
are deleted and the seat is freed; the employer keeps the attendance records. If
an owner deletes their account, the business is deleted along with its
workplaces, attendance records, corrections and audit trail.

## Your choices

You can ask your employer to correct an attendance record; owners make
corrections with a required reason and an audit trail. You can delete your
account in the app under **Account → Delete account**. You can also ask your
employer or the publisher to help with access, correction or deletion requests.

## Security

Traffic is encrypted in transit. Database access is enforced with row-level
security, and attendance decisions (method, state, geofence) are validated on
the server, never trusted from the phone. The app asks only for internet,
foreground location and — when you open the scanner — camera access.

## Children

This is a workplace tool for employees and business owners. It is not directed
at children and we do not knowingly collect data from children.

## Changes

If this policy changes, the updated version appears in the app and in this
published policy.

## Contact

Questions about this policy, or requests to access, correct or delete data:
**[PUBLISHER CONTACT — replace with a monitored email address before hosting]**.
Employees may also contact their employer, who controls the attendance records.
