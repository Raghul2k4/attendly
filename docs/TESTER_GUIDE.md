# Tester guide — Attendance (two-phone walkthrough)

Thank you for testing Attendance. This guide asks you to use **two Android
phones at the same time**: one as the business owner, one as an employee. Some
features (QR attendance, live attendance visibility, seat limits) cannot be
tested honestly on a single phone.

- **Phone A — Owner.** Creates the test business, configures the workplace and
  rules, adds the employee, and checks the reports.
- **Phone B — Employee.** Joins with the invite, punches in and out, scans the QR
  shown on Phone A.

Keep both phones with you, connected to the internet, with location turned on.
Allow about **60 minutes**.

> Use a **test business** and **test accounts only**. Do not enter real staff
> names, real customer data, or a real business you cannot delete. The data you
> create lives in the live backend.

---

## 1. What you need

| Item | Notes |
| --- | --- |
| Phone A | Android 7.0 or newer, internet, location on |
| Phone B | Android 7.0 or newer, internet, location on, camera |
| App file | `attendance-1.0.0-arm64-v8a.apk` (given to you by the developer) |
| Email addresses | Two addresses you can open (one per phone) |
| Passwords | At least 8 characters each |
| Location | Both phones at the same place (home/office), within 100 m of the workplace you will set |

If you already have an older **Attendance** app on either phone, uninstall it
first. Android will refuse to install this release build over a debug build
("App not installed") because they are signed with different keys. Uninstalling
removes only local app data; attendance data already on the server is not
deleted.

### Install on both phones

1. Copy the APK to each phone (USB, Google Drive, or a direct message).
2. Open the file and allow "Install unknown apps" for the app you used to open it.
3. Install and open **Attendance**.
4. Both phones should show the welcome screen with **I own a business**,
   **I am an employee**, and **I already have an account**.

Write down what you see if either phone shows a blank screen, a spinner that
never ends, or an error.

---

## 2. Create the owner account (Phone A)

1. Tap **I own a business**.
2. Tap **Create an account**.
3. Enter your name, the **Phone A email**, and a password. Tap **Create account**.
4. If the app says it sent a verification email, open that inbox, follow the
   link, then return and **Sign in**. Check the spam folder if it does not arrive.
5. You should land on **Create your business**.

Record:

- Owner email: ______________________________
- Owner password: ___________________________

---

## 3. Create the test business and workplace (Phone A)

1. Enter a business name such as `Tester Cafe <your name>`.
2. Keep the timezone the app detected (or change it), then tap **Create business**.
3. You should see the owner dashboard with **Seats** (1 of 15 used), **Team**,
   **Today**, and **Add staff**.

### Attendance rules

1. Open **Attendance rules**.
2. Enable **App button** and **QR code**.
3. Set working days to Monday–Friday (or all days).
4. Set **Start time** to `09:00` and **Grace period** to `10` minutes.
5. Save. You should see a confirmation, and the dashboard subtitle should
   reflect the new policy.

### Workplace

1. Return to the dashboard and open **Workplaces**.
2. Tap **Add workplace** (or **Add your first workplace**).
3. Name it `Test Site`.
4. Place the marker **at your current location** (use the location button, then
   confirm the marker). Do not guess the position.
5. Set the radius to **100 m** and save.
6. The workplace should appear in the list with its radius.

### Workplace QR

1. On the workplace, open the **Workplace QR** card.
2. Tap **Generate QR**. A QR code appears, plus a copyable code string.
3. **Keep this screen visible on Phone A during the QR test.** Turn the
   brightness up.

### Add the employee

1. Go back to the dashboard and tap **Add staff**.
2. Enter the employee's name (the person holding Phone B).
3. Tap **Create invite**.
4. The sheet shows a **STAFF CODE** (permanent) and an **INVITE TOKEN** (shown
   only once).
5. Tap **Copy invite details**, then send them to Phone B (message/email to
   yourself is fine).

Record:

- Business name: ____________________________
- Workplace + radius: _______________________
- Staff code: _______________________________
- Invite token: _____________________________ (shown once — copy it now)

> If you close the sheet without copying the token, the app cannot show it
> again. This is a known limitation for 1.0: the owner must delete and recreate
> the invitation. Note the problem in your report.

---

## 4. Join as the employee (Phone B)

1. Tap **I am an employee**.
2. Tap **Create an account** and register with the **Phone B email** and a
   different password. Confirm the email if asked, then sign in.
3. The app asks for an invite token (or shows **Join with an invite token**).
4. Paste the **INVITE TOKEN** from Phone A and tap **Join organisation**.
5. You should see the employee home with the business name, `Test Site`, and
   **Not checked in** / **Ready when you are.**

Record:

- Employee email: ___________________________
- Employee password: ________________________

Expected if something is wrong:

- A malformed token is rejected **before** any network call.
- A used or unknown token shows a specific message, not a generic error.
- A token from another business must not join you to a business you were not
  invited to.

---

## 5. Punch in with the app button (Phone B)

1. Make sure Phone B is inside the 100 m radius (**both phones at the workplace
   you placed**).
2. Tap **Punch in**.
3. Android asks for location permission. Choose **While using the app**.
4. Wait for the server confirmation. Expected:
   - a confirmed message with the check-in time ("Checked in at …"),
   - the card switches to **CHECKED IN**,
   - a live duration starts counting.
5. Tap **Punch in** again quickly (double-tap test). Expected: the button is
   disabled while recording, and no second session is created.

**Late arrival:** if the current time is after `09:10`, the card should show a
**LATE ARRIVAL** badge. If you started before `09:00`, it should not. The badge
is decided by the server at check-in; changing the start time later must not
change an existing record.

### Test a rejected punch (important)

1. Walk or drive about **200 m away** from the workplace (or set the workplace
   marker 200 m away from where you stand and save it).
2. Tap **Punch out**. Expected:
   - **no success message**, no closed session;
   - a specific rejection such as "You're outside the permitted workplace
     area", showing the distance;
   - the card still says **CHECKED IN** when you return/refresh.
3. Return inside the radius and tap **Punch out** again.
4. Expected: the server confirms the check-out time, the session shows
   **DAY COMPLETE**, and the duration matches the time between the two server
   times.

### Other rejection checks

- Turn **location off** in Android settings → Punch in shows a location prompt
  and never claims success.
- Deny location permission → the app explains the problem and offers Settings;
  no attendance is recorded.
- Turn on **airplane mode** → Punch in explains that attendance cannot be
  verified; no success, no queued fake punch. Turn the network back on, retry,
  and confirm the server state did not change while offline.

---

## 6. Punch with the workplace QR (Phone B)

1. On Phone A, keep the **Workplace QR** screen open (from step 3).
2. On Phone B, after a successful punch-out (or on a fresh day), tap
   **Scan QR instead** (or **Scan QR code** when both methods are enabled).
3. Allow camera permission.
4. Scan the QR displayed on Phone A.
5. Expected: location is acquired, the QR is validated by the server, and the
   punch is confirmed exactly like the app-button punch.

### QR rejection checks

- On Phone A tap **Revoke** (confirm). On Phone B, scan the old code again.
  Expected: "QR code is no longer valid…" and no punch. Generate a new QR
  afterwards if you want to continue.
- On Phone A turn **QR code** off in **Attendance rules**. On Phone B, scanning
  should be rejected with a message that QR attendance is disabled.
- Deny camera permission on Phone B. Expected: an explanation and a Settings
  path; no punch, and location is handled separately from QR validation.

> The QR is a permanent printed code. Photographing and sharing it is possible;
> the server still checks membership, method, geofence and attendance state.
> Report anything that lets a punch succeed outside those rules.

---

## 7. What the owner sees (Phone A)

Refresh the dashboard (pull down) and check:

1. **Today** counts: Present, Checked in, Late, No record yet.
2. **Recent activity** shows the employee's name and times.
3. **Team** lists the employee with today's status and staff code.
4. Tap the employee → **View attendance**: today's session, duration, late flag,
   monthly summary, and history.
5. Open **Attendance report**:
   - Today / 7 days / This month presets;
   - filter by the employee;
   - period totals match the recorded session;
   - copy the CSV and confirm it contains only this business's records.
6. Open **Corrections** after the next step.

### Correct a check-out

1. In the report, open the employee's completed record and choose **Correct**.
2. Change the check-out time (for example to a time after the check-in).
3. Save **without a reason** first. Expected: validation blocks it.
4. Add a reason (5–500 characters) and save.
5. Expected: the record is labelled **Corrected**, the duration recalculates, and
   the **Corrections** screen shows who, when, why, and the before → after times.

### Deactivate and reactivate (Phone A + B)

1. Open the employee in **Team** → **Deactivate employee** and confirm.
2. Expected: the seat count frees up; the employee's history stays visible.
3. On Phone B, refresh. Expected: **Access paused**, and any punch is rejected
   by the server.
4. Reactivate the employee. Expected: the seat is used again and Phone B can
   punch after refreshing.

---

## 8. Account and privacy (both phones)

1. Open **Account** (person icon, top right).
2. Check the identity, business, and **Privacy policy**. The policy must open
   inside the app and be readable by scrolling.
3. **Sign out** on Phone B, sign in again. The attendance history and today's
   state must still be there.

### Delete accounts (only at the very end, test business only)

1. On **Phone B**: **Account → Delete account**. Type `DELETE`, confirm.
2. Expected: Phone B is signed out and cannot sign in. On Phone A, the seat is
   freed and the attendance records remain visible (the employer keeps them).
3. On **Phone A** (optional, only if you do not need the test business):
   **Account → Delete account** deletes the business, workplaces, invitations,
   attendance and audit history. This cannot be undone.
4. Do **not** do this on a business you want to keep.

---

## 9. Restart and session checks

- Force-close the app on both phones and reopen it. Expected: the signed-in
  session survives, and today's state matches the server.
- Reboot one phone, reopen the app. Same expectation.
- Change the phone clock manually (if allowed) and refresh. Expected: displayed
  attendance times still come from the server; a modified phone clock must not
  create or move a record.

---

## 10. Pass / fail checklist

Mark each item **PASS**, **FAIL**, or **N/A**, and add a note for every FAIL.

### Install and onboarding

- [ ] Release APK installs on both phones
- [ ] Welcome screen shows both role paths
- [ ] Owner can register and sign in
- [ ] Employee can register and sign in
- [ ] Verification email flow is understandable (if triggered)
- [ ] Business creation succeeds and shows the owner dashboard
- [ ] Employee joins with the invite token
- [ ] Invalid/used token is rejected with clear copy

### Owner setup

- [ ] Attendance rules save (methods, days, start time, grace)
- [ ] Workplace is placed on the map and confirmed
- [ ] Radius is saved and shown
- [ ] QR generates and is displayed once
- [ ] QR can be replaced (old code stops working)
- [ ] QR can be revoked
- [ ] Add staff shows staff code + invite token
- [ ] Seat usage updates after invite/claim/deactivation

### Employee attendance

- [ ] Punch in is confirmed by the server
- [ ] Live duration counts after punch in
- [ ] Double tap does not create a duplicate session
- [ ] Punch out is confirmed and duration is correct
- [ ] Late badge matches start time + grace
- [ ] Outside-geofence punch is rejected and keeps the session open
- [ ] Weak GPS accuracy is rejected with the reason
- [ ] Location off / permission denied is handled without a false success
- [ ] Airplane mode does not fake a successful punch
- [ ] QR scan punches successfully
- [ ] Revoked QR is rejected
- [ ] QR method disabled is rejected
- [ ] Camera permission denied is handled

### Owner visibility and corrections

- [ ] Today counts match real records
- [ ] Recent activity and checked-in list are correct
- [ ] Report presets and employee filter work
- [ ] CSV contains only this business's records
- [ ] Correction requires a reason
- [ ] Corrected record is labelled and duration is recomputed
- [ ] Corrections list shows actor, time, reason, before → after
- [ ] Deactivation frees the seat and keeps history
- [ ] Deactivated employee cannot punch
- [ ] Reactivation restores access

### Account, privacy, resilience

- [ ] Privacy policy opens and scrolls
- [ ] Sign out / sign in preserves data
- [ ] Restart preserves the session and server state
- [ ] Manual clock change does not alter records
- [ ] Employee deletion keeps employer attendance and frees the seat
- [ ] Owner deletion removes the business and its records

---

## 11. How to report a bug

Send each bug with:

1. **What you were doing** (Phone A or B, the exact screen).
2. **Steps to reproduce**, numbered.
3. **Expected** result.
4. **Actual** result, including the exact message.
5. **Time and timezone** (for example `21 Oct 2026, 15:42 IST`).
6. **Phone model and Android version** for both phones.
7. **Screenshot or screen recording**.
8. Whether location/camera permissions were granted, and whether the phone was
   online.
9. The test business name and employee name, so we can find the records.

Do not include passwords in screenshots or reports.

---

## 12. Known limitations (not bugs for 1.0)

- Attendance cannot be recorded offline, and the app never pretends it was.
- Location is read only while you punch or place a workplace; there is no
  background tracking.
- The owner dashboard refreshes on pull-to-refresh, not automatically. A
  deactivated employee may keep a stale screen until they refresh, but the
  server rejects their punches.
- The invite token is shown only once and cannot be re-issued yet; recreating
  the employee is the current workaround. This is planned for the next slice.
- A workplace QR is permanent until replaced or revoked; there is no print
  sheet yet, but the code is displayed and copyable.
- Corrections cover check-out times only.
- The free plan supports 15 active employees. Deactivating someone frees a seat
  and keeps their history.
- Map tiles currently use the public OpenStreetMap service (pilot only).
