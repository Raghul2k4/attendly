import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/organisation_models.dart';

/// Member status pill: Active (emerald), Invite sent (amber), Inactive
/// (neutral). Labels are spelled out — colour is never the only signal.
class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      MemberStatus.active => (
        'Active',
        AppColors.emerald50,
        AppColors.emerald700,
      ),
      MemberStatus.invited => (
        'Invite sent',
        AppColors.amber50,
        AppColors.amber600,
      ),
      MemberStatus.inactive => (
        'Inactive',
        AppColors.slate200.withValues(alpha: .45),
        AppColors.slate500,
      ),
    };
    return AppBadge(
      label: label,
      background: background,
      foreground: foreground,
    );
  }
}

/// Distinguishes the owner row from employees without implying attendance.
class OwnerBadge extends StatelessWidget {
  const OwnerBadge({super.key});

  @override
  Widget build(BuildContext context) => const AppBadge(
    label: 'Owner',
    background: AppColors.emerald50,
    foreground: AppColors.emerald700,
  );
}
