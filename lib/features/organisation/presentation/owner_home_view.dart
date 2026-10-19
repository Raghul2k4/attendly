import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../workplaces/presentation/workplace_providers.dart';
import '../domain/organisation_models.dart';
import 'organisation_providers.dart';
import 'widgets/invite_staff_sheet.dart';
import 'widgets/member_sheet.dart';
import 'widgets/status_chips.dart';
import 'widgets/surface_card.dart';

/// Owner dashboard: organisation identity, real seat usage and the live staff
/// roster. Attendance metrics land with the attendance slice — this screen
/// never shows numbers it cannot source from the database.
class OwnerHomeView extends ConsumerWidget {
  const OwnerHomeView({super.key, required this.account});

  final MyAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = account.organisation;
    if (organisation == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppErrorPanel(
            message: 'We couldn’t load your organisation. Try again.',
            kind: AppErrorKind.server,
            onRetry: () => ref.invalidate(myAccountProvider),
          ),
        ],
      );
    }

    final staff = ref.watch(staffProvider(organisation.id));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(staffProvider(organisation.id));
        await ref.read(staffProvider(organisation.id).future);
      },
      child: staff.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: const [
            SizedBox(
              height: 200,
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
                  : 'We couldn’t load your team. Try again.',
              kind: error is AppException ? error.kind : AppErrorKind.unknown,
              onRetry: () => ref.invalidate(staffProvider(organisation.id)),
            ),
          ],
        ),
        data: (members) => _OwnerDashboard(
          account: account,
          organisation: organisation,
          members: members,
        ),
      ),
    );
  }
}

class _OwnerDashboard extends ConsumerWidget {
  const _OwnerDashboard({
    required this.account,
    required this.organisation,
    required this.members,
  });

  final MyAccount account;
  final Organisation organisation;
  final List<Membership> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final employees = members
        .where((member) => !member.isOwner)
        .toList(growable: false);
    final ownerMember = members.ownerMember;
    final plan = account.plan;
    final limit = plan?.maxActiveEmployees ?? 15;
    final used = members.activeEmployees;
    final pending = members.pendingInvites;
    final workplaces = ref.watch(workplacesProvider(organisation.id));
    final workplaceSummary = workplaces.when(
      data: (list) => list.isEmpty
          ? 'Add your first location and check-in radius'
          : '${list.length} ${list.length == 1 ? 'location' : 'locations'} '
                '· Manage geofence and QR codes',
      loading: () => 'Set locations, check-in radius and QR codes',
      error: (error, stackTrace) =>
          'Set locations, check-in radius and QR codes',
    );

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
            InitialAvatar(initials: organisation.initial, size: 48),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(organisation.name, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${organisation.timezone} · Business account',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Seats', style: textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '$used of $limit used',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.emerald700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: limit == 0 ? 0 : (used / limit).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: AppColors.slate200,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${plan?.displayName ?? 'Free'} plan includes $limit active '
                'staff. Deactivating someone frees their seat — their '
                'attendance history is kept.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              if (pending > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  pending == 1
                      ? '1 invite is waiting to be accepted — it doesn’t use a '
                            'seat yet.'
                      : '$pending invites are waiting to be accepted — they '
                            'don’t use seats yet.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.amber600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _WorkplacesEntry(subtitle: workplaceSummary),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text('Team', style: textTheme.titleMedium),
            const Spacer(),
            Text(
              '${employees.length} ${employees.length == 1 ? 'person' : 'people'}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: () => InviteStaffSheet.show(
            context,
            organisationId: organisation.id,
            organisationName: organisation.name,
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add staff'),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (ownerMember != null) ...[
          _OwnerTile(owner: ownerMember),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (employees.isEmpty)
          const _EmptyTeam()
        else
          for (final employee in employees)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StaffTile(
                member: employee,
                onTap: () => MemberSheet.show(
                  context,
                  organisationId: organisation.id,
                  member: employee,
                ),
              ),
            ),
      ],
    );
  }
}

class _WorkplacesEntry extends StatelessWidget {
  const _WorkplacesEntry({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.push('/workplaces'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: AppColors.emerald700,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workplaces', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
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

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.member, required this.onTap});

  final Membership member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              InitialAvatar(initials: member.initials),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.fullName, style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      member.employeeCode ?? 'No staff code',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MemberStatusChip(status: member.status),
              const SizedBox(width: AppSpacing.xs),
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

class _OwnerTile extends StatelessWidget {
  const _OwnerTile({required this.owner});

  final Membership owner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InitialAvatar(initials: owner.initials),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.fullName, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Business owner',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          const OwnerBadge(),
        ],
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        children: [
          const Icon(
            Icons.groups_outlined,
            size: AppIconSize.lg,
            color: AppColors.slate400,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No employees yet', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add your first team member to create their staff code and a '
            'one-time invite token.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
