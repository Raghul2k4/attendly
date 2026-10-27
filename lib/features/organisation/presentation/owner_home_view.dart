import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../attendance/domain/attendance_format.dart';
import '../../attendance/domain/attendance_history_models.dart';
import '../../attendance/presentation/attendance_providers.dart';
import '../../workplaces/presentation/workplace_providers.dart';
import '../domain/organisation_models.dart';
import 'organisation_providers.dart';
import 'widgets/invite_staff_sheet.dart';
import 'widgets/member_sheet.dart';
import '../../../core/widgets/surface_card.dart';
import 'widgets/status_chips.dart';

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
        ref.invalidate(ownerAttendanceOverviewProvider(organisation.id));
        try {
          await Future.wait([
            ref.read(staffProvider(organisation.id).future),
            ref.read(ownerAttendanceOverviewProvider(organisation.id).future),
          ]);
        } catch (_) {
          // Both providers render their own recoverable error states.
        }
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
    final limit = plan?.maxActiveEmployees;
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
    final attendanceSettings = ref.watch(
      attendanceSettingsProvider(organisation.id),
    );
    final attendanceSummary = attendanceSettings.when(
      data: (settings) {
        final methods = settings.appPunchEnabled && settings.qrPunchEnabled
            ? 'App + QR'
            : settings.qrPunchEnabled
            ? 'QR code'
            : settings.appPunchEnabled
            ? 'App button'
            : 'No method enabled';
        return '$methods · ${_workingDaysLabel(settings.workingDays)} · '
            '${settings.startTime} start';
      },
      loading: () => 'Methods, workdays, start time and late grace',
      error: (error, stackTrace) =>
          'Review methods, workdays and lateness rules',
    );
    final overview = ref.watch(
      ownerAttendanceOverviewProvider(organisation.id),
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
        _TodayOverviewCard(
          overview: overview,
          onRetry: () =>
              ref.invalidate(ownerAttendanceOverviewProvider(organisation.id)),
          onOpenReport: () => context.push('/attendance-report'),
        ),
        const SizedBox(height: AppSpacing.lg),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Team', style: textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    used == 1 ? '1 active staff' : '$used active staff',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.emerald700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (limit != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: limit == 0 ? 0 : (used / limit).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.slate200,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                limit == null
                    ? '${plan?.displayName ?? 'Free'} plan — unlimited staff, '
                          'no seat limit. Deactivating someone pauses their '
                          'access and keeps their attendance history.'
                    : '${plan?.displayName ?? 'Free'} plan includes $limit '
                          'active staff. Deactivating someone frees their seat '
                          '— their attendance history is kept.',
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
        _DashboardEntry(
          icon: Icons.place_outlined,
          title: 'Workplaces',
          subtitle: workplaceSummary,
          onTap: () => context.push('/workplaces'),
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardEntry(
          icon: Icons.fact_check_outlined,
          title: 'Attendance rules',
          subtitle: attendanceSummary,
          onTap: () => context.push('/attendance-settings'),
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardEntry(
          icon: Icons.insights_outlined,
          title: 'Attendance report',
          subtitle: 'Daily records, late arrivals, open sessions and CSV',
          onTap: () => context.push('/attendance-report'),
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardEntry(
          icon: Icons.history_toggle_off_rounded,
          title: 'Corrections',
          subtitle: 'Manual changes to recorded attendance, with reasons',
          onTap: () => context.push('/attendance-corrections'),
        ),
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

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.overview,
    required this.onRetry,
    required this.onOpenReport,
  });

  final AsyncValue<OwnerAttendanceOverview> overview;
  final VoidCallback onRetry;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: overview.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Today', style: textTheme.titleMedium)),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading recorded attendance...',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error is AppException
                  ? error.message
                  : 'Today\'s attendance couldn\'t be loaded.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.rose600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (data) =>
            _OverviewData(overview: data, onOpenReport: onOpenReport),
      ),
    );
  }
}

class _OverviewData extends StatelessWidget {
  const _OverviewData({required this.overview, required this.onOpenReport});

  final OwnerAttendanceOverview overview;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final openSessions = overview.openSessions;
    final recent = overview.recentSessions.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat('EEEE, d MMMM').format(overview.today),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onOpenReport, child: const Text('Report')),
          ],
        ),
        if (!overview.isWorkingDay) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Today isn\'t a configured working day. Recorded attendance is '
            'still shown.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.amber600),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OverviewMetric(
                label: 'Present',
                value: '${overview.presentTodayCount}',
                valueColor: AppColors.emerald700,
              ),
            ),
            Expanded(
              child: _OverviewMetric(
                label: 'Checked in',
                value: '${overview.checkedInNowCount}',
              ),
            ),
            Expanded(
              child: _OverviewMetric(
                label: 'Late',
                value: '${overview.lateTodayCount}',
                valueColor: overview.lateTodayCount > 0
                    ? AppColors.amber600
                    : null,
              ),
            ),
            Expanded(
              child: _OverviewMetric(
                label: 'No record yet',
                value: '${overview.noRecordTodayCount}',
                valueColor: AppColors.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${overview.activeEmployeeCount} active '
          '${overview.activeEmployeeCount == 1 ? 'employee' : 'employees'}. '
          'No record is not counted as an absence.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        if (overview.unresolvedPriorCount > 0) ...[
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
                  Icons.warning_amber_rounded,
                  size: AppIconSize.sm,
                  color: AppColors.amber600,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    overview.unresolvedPriorCount == 1
                        ? 'One session is still open from a previous day. It '
                              'needs review.'
                        : '${overview.unresolvedPriorCount} sessions are still '
                              'open from previous days. They need review.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.amber600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: AppSpacing.xxl),
        Text('Checked in now', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (openSessions.isEmpty)
          Text(
            'No one is checked in right now.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          )
        else
          for (final session in openSessions) ...[
            _OpenSessionRow(session: session),
            if (session != openSessions.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        if (recent.isNotEmpty) ...[
          const Divider(height: AppSpacing.xxl),
          Text('Recent activity', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in recent) ...[
            _RecentActivityRow(entry: entry, today: overview.today),
            if (entry != recent.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _OpenSessionRow extends StatelessWidget {
  const _OpenSessionRow({required this.session});

  final AttendanceOpenSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sinceLabel = session.isStaleOpen
        ? 'Since ${DateFormat('d MMM').format(session.workDate)}, '
              '${session.checkInTime}'
        : 'Since ${session.checkInTime}';
    return Row(
      children: [
        _SmallInitials(name: session.memberName),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.memberName, style: textTheme.bodyMedium),
              Text(
                sinceLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: session.isLate || session.isStaleOpen
                      ? AppColors.amber600
                      : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        if (session.isLate)
          const AppBadge(
            label: 'Late',
            background: AppColors.amber50,
            foreground: AppColors.amber600,
          ),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.entry, required this.today});

  final AttendanceHistoryEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final datePrefix = isSameCalendarDay(entry.workDate, today)
        ? ''
        : '${DateFormat('d MMM').format(entry.workDate)} - ';
    final activity = entry.isOpen
        ? '${datePrefix}In ${entry.checkInTime}, still checked in'
        : '${datePrefix}In ${entry.checkInTime}, out '
              '${entry.checkOutTime ?? '--:--'}'
              '${entry.crossesMidnight ? ' next day' : ''}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallInitials(name: entry.memberName),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.memberName, style: textTheme.bodyMedium),
              Text(
                activity,
                style: textTheme.bodySmall?.copyWith(
                  color: entry.isLate || entry.isOpen
                      ? AppColors.amber600
                      : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        if (entry.displayDuration != null)
          Text(
            formatWorked(entry.displayDuration!),
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.slate500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _SmallInitials extends StatelessWidget {
  const _SmallInitials({required this.name});

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
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.emerald50,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.emerald700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardEntry extends StatelessWidget {
  const _DashboardEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.emerald700),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleSmall),
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

String _workingDaysLabel(Set<int> days) {
  if (days.isEmpty) return 'No working days';
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) {
    return 'Mon–Fri';
  }
  if (days.length == 6 && days.containsAll(const {1, 2, 3, 4, 5, 6})) {
    return 'Mon–Sat';
  }
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final sorted = days.toList()..sort();
  return sorted.map((day) => labels[day - 1]).join(', ');
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
