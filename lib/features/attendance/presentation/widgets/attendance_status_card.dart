import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/attendance_format.dart';
import '../../domain/attendance_models.dart';

/// The single most important surface on the employee home: current state, live
/// duration and the one valid next action. Nothing here is shown before the
/// server confirms it.
class AttendanceStatusCard extends StatelessWidget {
  const AttendanceStatusCard({
    super.key,
    required this.today,
    required this.now,
    required this.punching,
    required this.onPunch,
    required this.onScanQr,
  });

  final AttendanceToday today;
  final DateTime now;
  final bool punching;
  final VoidCallback onPunch;

  /// Opens the workplace scanner. Null only when the caller cannot provide a
  /// functioning scanner; a QR-only policy then renders an honest explanation
  /// rather than a dead button.
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = today.session;
    final workplace = today.workplace;
    final action = today.nextAction;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: today.hasOpenSession ? AppColors.emerald50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: today.hasOpenSession
              ? AppColors.emerald600.withValues(alpha: .25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusPill(state: today.state),
              if (session?.isLate ?? false) const _LatePill(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (today.isComplete) ...[
            Text(
              formatWorked(session?.worked ?? Duration.zero),
              style: textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'worked today',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            ),
          ] else if (today.hasOpenSession) ...[
            Text(
              formatTimer(session!.elapsed(now)),
              style: textTheme.displaySmall?.copyWith(
                letterSpacing: .5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.workDate == today.workDate
                  ? 'Since ${session.checkInTime}'
                  : 'Since yesterday at ${session.checkInTime}',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink600),
            ),
          ] else ...[
            Text('Ready when you are.', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              workplace == null
                  ? 'Punch in once your owner adds a workplace.'
                  : 'Punch in when you reach ${workplace.name}.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink600),
            ),
          ],
          if (workplace != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: AppIconSize.sm,
                  color: AppColors.slate500,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${workplace.name} · ${workplace.radiusMeters} m radius',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          ..._actionArea(context, action),
        ],
      ),
    );
  }

  List<Widget> _actionArea(BuildContext context, PunchAction? action) {
    final textTheme = Theme.of(context).textTheme;

    if (today.isComplete) {
      return [
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.emerald600,
              size: AppIconSize.md,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Today’s attendance is complete.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.emerald700,
                ),
              ),
            ),
          ],
        ),
      ];
    }

    if (!today.settings.anyPunchEnabled) {
      return [
        _InlineWarning(
          message:
              'Your owner has turned off attendance methods for now. Ask them '
              'to enable app or QR punching.',
        ),
      ];
    }

    if (today.workplace == null) {
      return [
        _InlineWarning(
          message:
              'No active workplace is set up. Ask your owner to add one before '
              'punching.',
        ),
      ];
    }

    final appEnabled = today.settings.appPunchEnabled;
    final qrEnabled = today.settings.qrPunchEnabled;
    if (!appEnabled && (onScanQr == null || !qrEnabled)) {
      return [
        _InlineWarning(
          message:
              'Your owner has turned off app punching, but QR scanning isn’t '
              'available here. Ask them to enable app punching or update the '
              'app.',
        ),
      ];
    }

    final isOut = action == PunchAction.punchOut;
    final label = action?.buttonLabel ?? 'Punch in';
    final appIcon = isOut ? Icons.logout_rounded : Icons.login_rounded;
    final spinner = punching
        ? const SizedBox(
            width: AppIconSize.sm,
            height: AppIconSize.sm,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.surface,
            ),
          )
        : null;

    return [
      if (appEnabled)
        ElevatedButton.icon(
          onPressed: punching ? null : onPunch,
          icon: spinner ?? Icon(appIcon),
          label: Text(punching ? 'Recording…' : label),
        )
      else
        ElevatedButton.icon(
          onPressed: punching ? null : onScanQr,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(punching ? 'Recording…' : 'Scan QR code'),
        ),
      if (appEnabled && qrEnabled && onScanQr != null) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: punching ? null : onScanQr,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: AppIconSize.sm),
          label: const Text('Scan QR instead'),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.my_location_rounded,
            size: AppIconSize.sm,
            color: AppColors.slate500,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _methodHelp(action, appEnabled, qrEnabled),
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ),
        ],
      ),
    ];
  }

  String _methodHelp(PunchAction? action, bool appEnabled, bool qrEnabled) {
    if (appEnabled && qrEnabled) {
      return 'Your location is checked securely on the server after a punch or '
          'QR scan.';
    }
    if (appEnabled) {
      return 'Your location is checked securely on the server when you punch.';
    }
    final verb = action == PunchAction.punchOut ? 'punch out' : 'punch in';
    return 'Scan the printed workplace code to $verb. Your location is checked '
        'after the scan.';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final AttendanceDayState state;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (state) {
      AttendanceDayState.checkedIn => (
        'CHECKED IN',
        AppColors.emerald600,
        AppColors.surface,
      ),
      AttendanceDayState.completed => (
        'DAY COMPLETE',
        AppColors.ink900,
        AppColors.surface,
      ),
      AttendanceDayState.notStarted => (
        'NOT CHECKED IN',
        AppColors.slate200,
        AppColors.ink700,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _LatePill extends StatelessWidget {
  const _LatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'LATE ARRIVAL',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.amber600,
          fontWeight: FontWeight.w600,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: AppIconSize.sm,
            color: AppColors.amber600,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.amber600),
            ),
          ),
        ],
      ),
    );
  }
}
