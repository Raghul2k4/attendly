import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../domain/attendance_history_models.dart';
import '../domain/attendance_period.dart';
import 'attendance_providers.dart';
import 'widgets/attendance_history_summary_card.dart';
import 'widgets/attendance_record_card.dart';

/// Employee attendance history. The server picks the current organisation-local
/// month when no explicit range is supplied, then formats every time in the
/// organisation timezone.
class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  DateTime? _monthAnchor;

  MyAttendanceHistoryQuery _query(String organisationId) => (
    organisationId: organisationId,
    from: _monthAnchor == null ? null : firstDayOfMonth(_monthAnchor!),
    to: _monthAnchor == null ? null : lastDayOfMonth(_monthAnchor!),
  );

  void _previousMonth(AttendanceHistory history) {
    setState(() {
      _monthAnchor = firstDayOfMonthOffset(history.from, -1);
    });
  }

  void _nextMonth(AttendanceHistory history) {
    if (!history.canMoveNextMonth) return;
    final next = firstDayOfMonthOffset(history.from, 1);
    setState(() {
      _monthAnchor = isMonthAtOrAfter(next, history.today) ? null : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: SafeArea(
        top: false,
        child: accountAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              AppErrorPanel(
                message: error is AppException
                    ? error.message
                    : 'We couldn\'t load your account. Try again.',
                kind: error is AppException ? error.kind : AppErrorKind.unknown,
                onRetry: () => ref.invalidate(myAccountProvider),
              ),
            ],
          ),
          data: (account) {
            final organisation = account?.organisation;
            if (account == null || organisation == null) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message:
                        'Your organisation isn\'t available right now. Go '
                        'back and try again.',
                    kind: AppErrorKind.server,
                    onRetry: () => ref.invalidate(myAccountProvider),
                  ),
                ],
              );
            }
            if (!account.membership.isActive || account.membership.isOwner) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message:
                        'Only active employees have a personal attendance '
                        'history.',
                    kind: AppErrorKind.permission,
                    onRetry: () => ref.invalidate(myAccountProvider),
                  ),
                ],
              );
            }

            final query = _query(organisation.id);
            final historyAsync = ref.watch(myAttendanceHistoryProvider(query));
            return historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message: error is AppException
                        ? error.message
                        : 'We couldn\'t load your attendance history. Try '
                              'again.',
                    kind: error is AppException
                        ? error.kind
                        : AppErrorKind.unknown,
                    onRetry: () =>
                        ref.invalidate(myAttendanceHistoryProvider(query)),
                  ),
                ],
              ),
              data: (history) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myAttendanceHistoryProvider(query));
                  try {
                    await ref.read(myAttendanceHistoryProvider(query).future);
                  } catch (_) {
                    // The provider renders the recoverable error state.
                  }
                },
                child: _HistoryBody(
                  history: history,
                  onPreviousMonth: () => _previousMonth(history),
                  onNextMonth: () => _nextMonth(history),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.history,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final AttendanceHistory history;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(history.from),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: history.canMoveNextMonth ? onNextMonth : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AttendanceHistorySummaryCard(
          summary: history.summary,
          recordLabel: 'Days',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (history.isEmpty)
          const _EmptyHistory()
        else ...[
          Row(
            children: [
              Expanded(
                child: Text('Daily records', style: textTheme.titleMedium),
              ),
              Text(
                '${history.sessions.length} '
                '${history.sessions.length == 1 ? 'day' : 'days'}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in history.sessions) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                DateFormat('EEEE, d MMMM').format(entry.workDate),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.slate500,
                ),
              ),
            ),
            AttendanceRecordCard(entry: entry),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Times are shown in ${history.timezone}. An overnight session is '
          'recorded on the day it started.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 52,
            color: AppColors.slate400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No attendance records this month',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Completed check-ins will appear here with their server-confirmed '
            'times.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
