import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/attendance_format.dart';
import '../../domain/attendance_models.dart';

/// Today's recorded evidence, sourced from the server session row only.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key, required this.today});

  final AttendanceToday today;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = today.session;
    final hasSession = session != null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today’s session',
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (today.isComplete)
                Text(
                  'Complete',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.emerald700,
                  ),
                )
              else if (today.hasOpenSession)
                Text(
                  'In progress',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.emerald700,
                  ),
                )
              else
                Text(
                  'Not started',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!hasSession)
            Text(
              'No attendance recorded yet today.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            )
          else ...[
            _ValueRow(label: 'Checked in', value: session.checkInTime),
            const SizedBox(height: AppSpacing.md),
            _ValueRow(
              label: 'Checked out',
              value: session.checkOutTime ?? 'In progress',
            ),
            const SizedBox(height: AppSpacing.md),
            _ValueRow(
              label: 'Worked',
              value: session.isCompleted
                  ? formatWorked(session.worked)
                  : formatElapsed(session.elapsed()),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.border.withValues(alpha: .8)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: AppIconSize.sm,
                color: AppColors.slate500,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Workday starts ${today.settings.startTime} · '
                  '${today.settings.graceMinutes} min grace',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Times are shown in ${today.timezone}.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
