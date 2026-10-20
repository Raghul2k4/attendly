import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../organisation/domain/organisation_models.dart';
import '../../domain/attendance_format.dart';
import '../../domain/attendance_history_models.dart';

/// One attendance record, with every value taken from the server response.
/// The owning screen supplies the date heading so repeated dates stay grouped.
class AttendanceRecordCard extends StatelessWidget {
  const AttendanceRecordCard({
    super.key,
    required this.entry,
    this.showEmployee = false,
    this.onCorrect,
  });

  final AttendanceHistoryEntry entry;
  final bool showEmployee;

  /// Owner-only action that opens the correction sheet. When null the card is
  /// read-only, which is what employees see.
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exceptional = entry.isLate || entry.isOpen || entry.crossesMidnight;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEmployee || exceptional || entry.isCorrected) ...[
            if (showEmployee)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Initials(name: entry.memberName),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.memberName, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          entry.employeeCode ?? 'No staff code',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                            letterSpacing: .4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            if (showEmployee && exceptional)
              const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (entry.isLate)
                  const AppBadge(
                    label: 'Late arrival',
                    background: AppColors.amber50,
                    foreground: AppColors.amber600,
                  ),
                if (entry.isOpen)
                  AppBadge(
                    label: entry.isStaleOpen
                        ? 'Open from previous day'
                        : 'Still checked in',
                    background: AppColors.amber50,
                    foreground: AppColors.amber600,
                  ),
                if (entry.crossesMidnight)
                  AppBadge(
                    label: 'Overnight',
                    background: AppColors.slate200.withValues(alpha: .45),
                    foreground: AppColors.slate500,
                  ),
                if (entry.memberStatus == MemberStatus.inactive)
                  AppBadge(
                    label: 'Inactive staff',
                    background: AppColors.slate200.withValues(alpha: .45),
                    foreground: AppColors.slate500,
                  ),
                if (entry.isCorrected)
                  const AppBadge(
                    label: 'Corrected',
                    background: AppColors.emerald50,
                    foreground: AppColors.emerald700,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TimeCell(label: 'Checked in', value: entry.checkInTime),
              ),
              Expanded(
                child: _TimeCell(
                  label: 'Checked out',
                  value: entry.isOpen
                      ? 'Not yet'
                      : entry.crossesMidnight
                      ? '${entry.checkOutTime ?? '--:--'} +1d'
                      : entry.checkOutTime ?? '--:--',
                  warning: entry.isOpen,
                ),
              ),
              Expanded(
                child: _TimeCell(
                  label: entry.isOpen ? 'Elapsed' : 'Worked',
                  value: entry.displayDuration == null
                      ? '--'
                      : formatWorked(entry.displayDuration!),
                  warning: entry.isOpen,
                ),
              ),
            ],
          ),
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
                  entry.workplaceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
              ),
              if (entry.isCompleted) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  entry.isLate ? 'Completed - late' : 'Completed',
                  style: textTheme.labelSmall?.copyWith(
                    color: entry.isLate
                        ? AppColors.amber600
                        : AppColors.emerald700,
                  ),
                ),
              ],
            ],
          ),
          if (onCorrect != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onCorrect,
              icon: const Icon(
                Icons.edit_calendar_outlined,
                size: AppIconSize.sm,
              ),
              label: const Text('Correct check-out'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: warning ? AppColors.amber600 : AppColors.ink900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.emerald50,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.emerald700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
