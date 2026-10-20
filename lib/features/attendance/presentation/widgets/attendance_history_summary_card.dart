import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/attendance_format.dart';
import '../../domain/attendance_history_models.dart';

/// Period totals from server-recorded sessions. Open sessions are deliberately
/// excluded from the hours figure until they are checked out.
class AttendanceHistorySummaryCard extends StatelessWidget {
  const AttendanceHistorySummaryCard({
    super.key,
    required this.summary,
    this.showMemberCount = false,
    this.recordLabel = 'Records',
  });

  final AttendanceHistorySummary summary;
  final bool showMemberCount;
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Period totals', style: textTheme.titleMedium),
              ),
              if (showMemberCount && summary.memberCount > 0)
                Text(
                  '${summary.memberCount} '
                  '${summary.memberCount == 1 ? 'employee' : 'employees'}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  label: recordLabel,
                  value: '${summary.sessionCount}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Hours',
                  value: formatWorked(summary.totalWork),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Late',
                  value: '${summary.lateCount}',
                  valueColor: summary.lateCount > 0 ? AppColors.amber600 : null,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Open',
                  value: '${summary.openCount}',
                  valueColor: summary.openCount > 0 ? AppColors.amber600 : null,
                ),
              ),
            ],
          ),
          if (summary.openCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: AppIconSize.sm,
                    color: AppColors.amber600,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      summary.openCount == 1
                          ? 'One session is still open. It is not included in '
                                'the hours total until it is checked out.'
                          : '${summary.openCount} sessions are still open. '
                                'They are not included in the hours total until '
                                'they are checked out.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.amber600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(
            color: valueColor ?? AppColors.ink900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}
