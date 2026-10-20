import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/surface_card.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../domain/attendance_correction_models.dart';
import 'attendance_providers.dart';

/// Audit trail of attendance corrections for one organisation.
///
/// Every entry is a server-recorded adjustment: who corrected it, when, why,
/// and what the check-out was before and after. Records are never edited
/// silently, so this list is the owner's window into manual changes.
class AttendanceCorrectionsScreen extends ConsumerWidget {
  const AttendanceCorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Corrections')),
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
                        'Your organisation isn\'t available right now. Go back '
                        'and try again.',
                    kind: AppErrorKind.server,
                    onRetry: () => ref.invalidate(myAccountProvider),
                  ),
                ],
              );
            }
            if (!account.membership.isOwner) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message: 'Only the business owner can review corrections.',
                    kind: AppErrorKind.permission,
                    onRetry: () => ref.invalidate(myAccountProvider),
                  ),
                ],
              );
            }

            final correctionsAsync = ref.watch(
              attendanceCorrectionsProvider(organisation.id),
            );
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(attendanceCorrectionsProvider(organisation.id));
                try {
                  await ref.read(
                    attendanceCorrectionsProvider(organisation.id).future,
                  );
                } catch (_) {
                  // The provider renders the recoverable error state.
                }
              },
              child: correctionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    AppErrorPanel(
                      message: error is AppException
                          ? error.message
                          : 'We couldn\'t load the corrections. Try again.',
                      kind: error is AppException
                          ? error.kind
                          : AppErrorKind.unknown,
                      onRetry: () => ref.invalidate(
                        attendanceCorrectionsProvider(organisation.id),
                      ),
                    ),
                  ],
                ),
                data: (corrections) => corrections.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: const [_EmptyCorrections()],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.xxl,
                        ),
                        itemCount: corrections.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(
                                'Recorded attendance only changes when an owner '
                                'corrects it. The original punch record is kept.',
                              ),
                            );
                          }
                          final correction = corrections[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _CorrectionCard(correction: correction),
                          );
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});

  final AttendanceCorrection correction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(correction.memberName, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      correction.employeeCode ?? 'No staff code',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(
                label: DateFormat('d MMM').format(correction.workDate),
                background: AppColors.slate200.withValues(alpha: .45),
                foreground: AppColors.slate500,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: AppIconSize.sm,
                color: AppColors.amber600,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Check-out ${correction.changeLabel}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(correction.reason, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            correction.createdAtLocal.isEmpty
                ? 'by ${correction.actorName}'
                : 'by ${correction.actorName} · ${correction.createdAtLocal}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            correction.workplaceName,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}

class _EmptyCorrections extends StatelessWidget {
  const _EmptyCorrections();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.fact_check_outlined,
          size: AppIconSize.lg,
          color: AppColors.slate400,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('No corrections yet', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Nothing has been changed by hand. If a check-out is missing, correct '
          'it from the attendance report — the change is recorded with your '
          'name and reason.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}
