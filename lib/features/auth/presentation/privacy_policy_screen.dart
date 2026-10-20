import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';

/// Plain-language privacy policy shown inside the app and mirrored in
/// docs/legal/PRIVACY_POLICY.md (the copy to host before publishing).
///
/// It describes only what the app actually does: Supabase-hosted accounts,
/// foreground location captured when a punch or workplace marker is submitted,
/// attendance records kept by the employer, and in-app account deletion.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: const [
            Text(
              'Your attendance data belongs to you and your employer. This '
              'page explains what the app stores, why, and how to remove it.',
              style: TextStyle(height: 1.5),
            ),
            _Section(
              title: 'Who runs this app',
              body:
                  'The app is operated by the business that invited you (your '
                  'employer) using software provided by the app publisher. Your '
                  'employer decides which workplaces, schedules and attendance '
                  'methods apply to you. Use the contact details in the Play '
                  'Store listing for privacy questions.',
            ),
            _Section(
              title: 'What we store',
              body:
                  'Account: your name, email address and a securely hashed '
                  'password. The app never stores your password in readable '
                  'form.\n\n'
                  'Work: your business name, timezone, workplaces (name, map '
                  'coordinates and geofence radius), working days, start time, '
                  'grace period and attendance-method settings.\n\n'
                  'Attendance: check-in and check-out times, the method used, '
                  'the workplace, the location reported by your phone at the '
                  'moment of the punch (latitude, longitude, reported accuracy '
                  'and distance from the workplace), and whether the punch was '
                  'accepted or rejected.\n\n'
                  'Corrections: when an owner changes a check-out time, the '
                  'previous value, the new value, the reason and the owner who '
                  'made the change are kept.',
            ),
            _Section(
              title: 'Location',
              body:
                  'Location is used only in the foreground: when you punch in '
                  'or out, or when an owner places a workplace on the map. The '
                  'app does not track you in the background and does not collect '
                  'location between punches. A punch is rejected when the '
                  'reported accuracy is too low or the position is outside the '
                  'workplace geofence configured by your employer.',
            ),
            _Section(
              title: 'Why we use it',
              body:
                  'To sign you in, record attendance, apply your employer’s '
                  'schedules and grace period, verify that a punch happened at a '
                  'workplace, show attendance history and reports, and keep an '
                  'audit trail of owner corrections. We do not use this data for '
                  'advertising and the app contains no advertising or analytics '
                  'SDKs.',
            ),
            _Section(
              title: 'Who can see it',
              body:
                  'You can see your own profile and attendance history. The '
                  'owner of your business can see the attendance records of '
                  'their team. Other businesses cannot access your records — '
                  'access is enforced in the database, not only in the app. '
                  'Data is hosted by Supabase on our behalf. Map tiles are '
                  'requested from a map tile provider, which receives your IP '
                  'address as part of that request but never your location.',
            ),
            _Section(
              title: 'How long it is kept',
              body:
                  'Attendance records are kept for as long as your employer '
                  'needs them as business records. If an employee deletes their '
                  'account, the sign-in identity and profile are deleted and the '
                  'seat is freed; the employer keeps the attendance records. If '
                  'an owner deletes their account, the business is deleted along '
                  'with its workplaces, attendance records, corrections and '
                  'audit trail.',
            ),
            _Section(
              title: 'Your choices',
              body:
                  'You can ask your employer to correct an attendance record; '
                  'owners make corrections with a required reason and an audit '
                  'trail. You can delete your account in the app under Account → '
                  'Delete account. You can also ask your employer or the '
                  'publisher to help with access, correction or deletion '
                  'requests.',
            ),
            _Section(
              title: 'Security',
              body:
                  'Traffic is encrypted in transit. Database access is enforced '
                  'with row-level security, and attendance decisions (method, '
                  'state, geofence) are validated on the server, never trusted '
                  'from the phone. The app asks only for internet, foreground '
                  'location and — when you open the scanner — camera access.',
            ),
            _Section(
              title: 'Children',
              body:
                  'This is a workplace tool for employees and business owners. '
                  'It is not directed at children and we do not knowingly '
                  'collect data from children.',
            ),
            _Section(
              title: 'Changes',
              body:
                  'If this policy changes, the updated version appears here and '
                  'in the published policy linked from the Play Store listing.',
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'Last updated: 20 October 2026',
              style: TextStyle(color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.ink700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
