import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/utils/clipboard_copy.dart';
import '../domain/organisation_models.dart';
import 'widgets/surface_card.dart';

/// Employee home: identity, organisation and staff code — the facts that
/// exist today. Attendance punching is intentionally absent until the
/// attendance pipeline ships; nothing here pretends otherwise.
class EmployeeHomeView extends StatelessWidget {
  const EmployeeHomeView({super.key, required this.account});

  final MyAccount account;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final organisation = account.organisation;
    final member = account.membership;
    final code = member.employeeCode ?? '—';
    final firstName = member.fullName.trim().split(RegExp(r'\s+')).first;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Hi, $firstName', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          organisation == null
              ? 'You’re signed in.'
              : 'You’re part of ${organisation.name}.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (organisation != null)
          SurfaceCard(
            child: Row(
              children: [
                InitialAvatar(initials: organisation.initial, size: 48),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(organisation.name, style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        organisation.timezone,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (organisation != null) const SizedBox(height: AppSpacing.lg),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR STAFF CODE',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.slate500,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      code,
                      style: textTheme.headlineSmall?.copyWith(
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy staff code',
                    onPressed: () =>
                        copyToClipboard(context, code, label: 'Staff code'),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: AppIconSize.md,
                      color: AppColors.ink600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This identifies you to your owner. It is not a password — '
                'never use it to sign in.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: AppIconSize.md,
                color: AppColors.amber600,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance punching is next',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.amber600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Punch in and out from this screen once your workplace '
                      'and work hours are set up by your owner.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.amber600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
