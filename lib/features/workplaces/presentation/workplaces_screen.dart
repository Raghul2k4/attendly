import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../../organisation/presentation/widgets/surface_card.dart';
import '../domain/workplace_models.dart';
import 'workplace_providers.dart';

/// Owner screen listing every workplace, its radius and whether a printable
/// QR code is currently active.
class WorkplacesScreen extends ConsumerWidget {
  const WorkplacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(myAccountProvider);

    return accountAsync.when(
      loading: () => _shell(const Center(child: CircularProgressIndicator())),
      error: (error, _) => _shell(
        ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppErrorPanel(
              message: error is AppException
                  ? error.message
                  : 'We couldn’t load your organisation. Try again.',
              kind: error is AppException ? error.kind : AppErrorKind.unknown,
              onRetry: () => ref.invalidate(myAccountProvider),
            ),
          ],
        ),
      ),
      data: (account) {
        final organisation = account?.organisation;
        if (organisation == null) {
          return _shell(
            ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                AppErrorPanel(
                  message:
                      'Your organisation isn’t available right now. Go back '
                      'and try again.',
                  kind: AppErrorKind.server,
                  onRetry: () => ref.invalidate(myAccountProvider),
                ),
              ],
            ),
          );
        }

        final workplaces = ref.watch(workplacesProvider(organisation.id));
        final qrStatuses = ref.watch(qrStatusesProvider(organisation.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Workplaces'),
            actions: [
              IconButton(
                tooltip: 'Add workplace',
                onPressed: () => context.push('/workplaces/new'),
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(workplacesProvider(organisation.id));
                ref.invalidate(qrStatusesProvider(organisation.id));
                await Future.wait([
                  ref.read(workplacesProvider(organisation.id).future),
                  ref.read(qrStatusesProvider(organisation.id).future),
                ]);
              },
              child: workplaces.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: const [
                    SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    AppErrorPanel(
                      message: error is AppException
                          ? error.message
                          : 'We couldn’t load your workplaces. Try again.',
                      kind: error is AppException
                          ? error.kind
                          : AppErrorKind.unknown,
                      onRetry: () =>
                          ref.invalidate(workplacesProvider(organisation.id)),
                    ),
                  ],
                ),
                data: (list) => _WorkplaceList(
                  workplaces: list,
                  qrStatuses: qrStatuses.value,
                ),
              ),
            ),
          ),
          bottomNavigationBar: workplaces.value?.isEmpty ?? true
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: AppPrimaryButton(
                    label: 'Add workplace',
                    onPressed: () => context.push('/workplaces/new'),
                  ),
                ),
        );
      },
    );
  }

  Widget _shell(Widget child) => Scaffold(
    appBar: AppBar(title: const Text('Workplaces')),
    body: SafeArea(child: child),
  );
}

class _WorkplaceList extends StatelessWidget {
  const _WorkplaceList({required this.workplaces, required this.qrStatuses});

  final List<Workplace> workplaces;

  /// Null while QR metadata is loading or unavailable; the list then omits
  /// QR badges rather than claiming a code does or doesn’t exist.
  final Map<String, WorkplaceQrStatus>? qrStatuses;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (workplaces.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const Icon(Icons.place_outlined, size: 52, color: AppColors.slate400),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No workplaces yet',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add the place where your team works. You’ll set its location on a '
            'map, choose how close staff must be to check in, and generate a '
            'QR code if you use QR attendance.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/workplaces/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add your first workplace'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: AppIconSize.md,
                color: AppColors.teal600,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Employees can check in only inside the radius you set here. '
                  'A QR code is a separate, replaceable credential for each '
                  'workplace.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text('Your locations', style: textTheme.titleMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${workplaces.length} '
              '${workplaces.length == 1 ? 'workplace' : 'workplaces'}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final workplace in workplaces)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _WorkplaceTile(
              workplace: workplace,
              hasLiveQr: qrStatuses?.containsKey(workplace.id) ?? false,
              qrKnown: qrStatuses != null,
            ),
          ),
      ],
    );
  }
}

class _WorkplaceTile extends StatelessWidget {
  const _WorkplaceTile({
    required this.workplace,
    required this.hasLiveQr,
    required this.qrKnown,
  });

  final Workplace workplace;
  final bool hasLiveQr;
  final bool qrKnown;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.push('/workplaces/${workplace.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: workplace.isActive
                      ? AppColors.emerald50
                      : AppColors.slate200.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: workplace.isActive
                      ? AppColors.emerald700
                      : AppColors.slate500,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workplace.name, style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(
                          label: workplace.isActive ? 'Active' : 'Inactive',
                          background: workplace.isActive
                              ? AppColors.emerald50
                              : AppColors.slate200.withValues(alpha: .45),
                          foreground: workplace.isActive
                              ? AppColors.emerald700
                              : AppColors.slate500,
                        ),
                        if (qrKnown)
                          AppBadge(
                            label: hasLiveQr ? 'QR active' : 'No QR',
                            background: hasLiveQr
                                ? AppColors.teal600.withValues(alpha: .10)
                                : AppColors.slate200.withValues(alpha: .45),
                            foreground: hasLiveQr
                                ? AppColors.teal600
                                : AppColors.slate500,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${workplace.radiusMeters} m radius · '
                      '${workplace.coordinateLabel}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.md,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
