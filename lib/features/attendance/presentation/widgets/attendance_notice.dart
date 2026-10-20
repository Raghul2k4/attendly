import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';

enum AttendanceNoticeKind { accepted, warning, error }

class AttendanceNoticeData {
  const AttendanceNoticeData({
    required this.kind,
    required this.title,
    required this.message,
  });

  final AttendanceNoticeKind kind;
  final String title;
  final String message;
}

/// Persistent, specific feedback after a confirmed server decision. It stays
/// visible until the next attempt so a rejection cannot be missed.
class AttendanceNotice extends StatelessWidget {
  const AttendanceNotice({super.key, required this.data});

  final AttendanceNoticeData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (background, foreground, icon) = switch (data.kind) {
      AttendanceNoticeKind.accepted => (
        AppColors.emerald50,
        AppColors.emerald700,
        Icons.check_circle_rounded,
      ),
      AttendanceNoticeKind.warning => (
        AppColors.amber50,
        AppColors.amber600,
        Icons.warning_amber_rounded,
      ),
      AttendanceNoticeKind.error => (
        AppColors.rose50,
        AppColors.rose600,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: foreground.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: AppIconSize.md),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: textTheme.titleSmall?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    data.message,
                    style: textTheme.bodySmall?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
