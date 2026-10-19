import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';

/// Inline, recoverable error panel — never hides from the user: pairs each
/// error kind with a specific icon and a Retry affordance.
class AppErrorPanel extends StatelessWidget {
  const AppErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.kind = AppErrorKind.unknown,
  });

  factory AppErrorPanel.fromException(
    Object error, {
    Key? key,
    required VoidCallback onRetry,
  }) {
    final mapped = mapAuthError(error);
    return AppErrorPanel(
      key: key,
      message: mapped.message,
      kind: mapped.kind,
      onRetry: onRetry,
    );
  }

  final String message;
  final AppErrorKind kind;
  final VoidCallback onRetry;

  IconData get _icon => switch (kind) {
    AppErrorKind.network => Icons.wifi_off_rounded,
    AppErrorKind.permission => Icons.lock_outline_rounded,
    AppErrorKind.auth => Icons.key_off_rounded,
    AppErrorKind.conflict => Icons.error_outline_rounded,
    AppErrorKind.server => Icons.cloud_off_rounded,
    AppErrorKind.invalidInput => Icons.edit_off_rounded,
    AppErrorKind.unknown => Icons.help_outline_rounded,
  };

  bool get _retryUseful => switch (kind) {
    AppErrorKind.network || AppErrorKind.server => true,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.rose50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.rose600.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: AppColors.rose600, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.rose600,
                  ),
                ),
                if (_retryUseful) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.rose600,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(64, TouchTarget.minInteractive),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
