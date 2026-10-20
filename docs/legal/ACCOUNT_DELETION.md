# Account deletion — Attendance

Google Play requires apps that let people create an account to offer account
deletion. The app implements this in **Account → Delete account**; this page is
the web-facing copy to host for the Play Console "account deletion URL".

> **Before publishing:** host this text at a stable public HTTPS URL and enter
> that URL in Play Console → App content → Data deletion. Replace the
> publisher contact and the package name if they differ.

## Delete your account in the app

1. Open **Attendance** and sign in.
2. Open **Account** (person icon, top right).
3. Scroll to **Danger zone** and tap **Delete account**.
4. Type `DELETE` and confirm.

The request is processed immediately.

**If you are an employee:** your sign-in identity and profile are deleted, your
seat is freed, and you can no longer sign in. Your employer keeps the attendance
records it needs as business records (including your name on those records).

**If you are a business owner:** deleting your account deletes the business,
including its workplaces, staff invitations, attendance records, corrections and
audit trail. Team members lose access to the business. This cannot be undone.

## If you cannot sign in

Ask your employer (the business owner who invited you) to deactivate your
membership. To remove the sign-in identity itself, contact the publisher at the
address below from the email address on the account and ask for deletion.

## What is deleted

| Data | Employee | Owner |
| --- | --- | --- |
| Account email and password hash | Deleted | Deleted |
| Profile (name, timezone) | Deleted | Deleted |
| Membership / seat | Deactivated, user detached | Business deleted |
| Attendance records | Kept by the employer | Deleted with the business |
| Location evidence on punches | Kept with attendance records | Deleted with the business |
| Corrections and audit trail | Kept with the employer's records | Deleted with the business |
| Workplace QR tokens | Not affected | Deleted with the business |

## Contact

**[PUBLISHER CONTACT — replace with a monitored email address before hosting]**
