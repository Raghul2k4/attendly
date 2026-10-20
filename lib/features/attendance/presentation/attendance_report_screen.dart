import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/clipboard_copy.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/surface_card.dart';
import '../../organisation/domain/organisation_models.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../../organisation/presentation/widgets/status_chips.dart';
import '../domain/attendance_csv.dart';
import '../domain/attendance_history_models.dart';
import '../domain/attendance_period.dart';
import 'attendance_providers.dart';
import 'widgets/attendance_history_summary_card.dart';
import 'widgets/attendance_record_card.dart';

/// Owner attendance report. Date filtering uses the organisation's work date
/// from the server, never the phone's date; employee scope is validated again
/// by `get_attendance_report`.
class AttendanceReportScreen extends ConsumerStatefulWidget {
  const AttendanceReportScreen({
    super.key,
    this.initialMemberId,
    this.initialMemberName,
  });

  final String? initialMemberId;
  final String? initialMemberName;

  @override
  ConsumerState<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState
    extends ConsumerState<AttendanceReportScreen> {
  AttendanceReportRangePreset _preset = AttendanceReportRangePreset.thisMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  DateTime? _orgToday;
  String? _memberId;
  String? _initialMemberName;

  @override
  void initState() {
    super.initState();
    _memberId = widget.initialMemberId;
    _initialMemberName = widget.initialMemberName;
  }

  AttendanceReportQuery _query(String organisationId) {
    DateTime? from;
    DateTime? to;
    final today = _orgToday;
    if (_preset == AttendanceReportRangePreset.thisMonth && today == null) {
      from = null;
      to = null;
    } else if (_preset == AttendanceReportRangePreset.custom) {
      from = _customFrom;
      to = _customTo;
    } else if (today != null) {
      final range = attendanceRangeForPreset(_preset, today);
      from = range.from;
      to = range.to;
    }
    return (
      organisationId: organisationId,
      from: from,
      to: to,
      memberId: _memberId,
    );
  }

  Future<void> _pickCustomRange(AttendanceHistory history) async {
    final today = _orgToday ?? history.today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2, 1, 1),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _customFrom ?? history.from,
        end: _customTo ?? history.to,
      ),
      helpText: 'Attendance period',
      saveText: 'Use period',
    );
    if (picked == null || !mounted) return;
    final from = dateOnly(picked.start);
    final to = dateOnly(picked.end);
    if (to.difference(from).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reports can cover up to one year at a time.'),
        ),
      );
      return;
    }
    setState(() {
      _preset = AttendanceReportRangePreset.custom;
      _customFrom = from;
      _customTo = to;
    });
  }

  Future<void> _selectPreset(
    AttendanceReportRangePreset preset,
    AttendanceHistory history,
  ) async {
    if (preset == AttendanceReportRangePreset.custom) {
      await _pickCustomRange(history);
      return;
    }
    setState(() => _preset = preset);
  }

  Future<void> _pickMember(AttendanceHistory history) async {
    const allValue = '__all__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MemberPickerSheet(
        members: history.members,
        selectedId: _memberId,
        allValue: allValue,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selected == allValue) {
        _memberId = null;
        _initialMemberName = null;
      } else {
        _memberId = selected;
        _initialMemberName = _firstOrNull(
          history.members
              .where((member) => member.id == selected)
              .map((member) => member.fullName),
        );
      }
    });
  }

  String get _selectedName {
    if (_memberId == null) return 'All employees';
    return _initialMemberName ?? 'Selected employee';
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _memberId == null ? 'Attendance report' : 'Employee attendance',
        ),
      ),
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
            if (!account.membership.isOwner) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message: 'Only the business owner can view team reports.',
                    kind: AppErrorKind.permission,
                    onRetry: () => ref.invalidate(myAccountProvider),
                  ),
                ],
              );
            }

            final query = _query(organisation.id);
            final reportAsync = ref.watch(attendanceReportProvider(query));
            return reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AppErrorPanel(
                    message: error is AppException
                        ? error.message
                        : 'We couldn\'t load this report. Try again.',
                    kind: error is AppException
                        ? error.kind
                        : AppErrorKind.unknown,
                    onRetry: () =>
                        ref.invalidate(attendanceReportProvider(query)),
                  ),
                ],
              ),
              data: (history) {
                _orgToday = history.today;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(attendanceReportProvider(query));
                    try {
                      await ref.read(attendanceReportProvider(query).future);
                    } catch (_) {
                      // The provider renders the recoverable error state.
                    }
                  },
                  child: _ReportBody(
                    history: history,
                    preset: _preset,
                    customFrom: _customFrom,
                    customTo: _customTo,
                    selectedMemberId: _memberId,
                    selectedName: _selectedName,
                    onPresetSelected: (preset) =>
                        _selectPreset(preset, history),
                    onPickMember: () => _pickMember(history),
                    onCopyCsv: history.isEmpty
                        ? null
                        : () => copyToClipboard(
                            context,
                            buildAttendanceCsv(
                              history.sessions,
                              timezone: history.timezone,
                            ),
                            label: 'Attendance CSV',
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.history,
    required this.preset,
    required this.customFrom,
    required this.customTo,
    required this.selectedMemberId,
    required this.selectedName,
    required this.onPresetSelected,
    required this.onPickMember,
    required this.onCopyCsv,
  });

  final AttendanceHistory history;
  final AttendanceReportRangePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String? selectedMemberId;
  final String selectedName;
  final ValueChanged<AttendanceReportRangePreset> onPresetSelected;
  final VoidCallback onPickMember;
  final VoidCallback? onCopyCsv;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedMember = _firstOrNull(
      history.members.where((member) => member.id == selectedMemberId),
    );
    final grouped = <DateTime, List<AttendanceHistoryEntry>>{};
    for (final entry in history.sessions) {
      grouped.putIfAbsent(entry.workDate, () => []).add(entry);
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
        Text(
          'Recorded attendance only, formatted in ${history.timezone}. '
          'Changing the period or employee never changes a stored time.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.lg),
        _FilterCard(
          preset: preset,
          customFrom: customFrom,
          customTo: customTo,
          rangeLabel: _rangeLabel(history.from, history.to),
          selectedName: selectedMember?.fullName ?? selectedName,
          hasMemberFilter: history.members.isNotEmpty,
          onPresetSelected: onPresetSelected,
          onPickMember: onPickMember,
        ),
        if (selectedMember != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _MemberIdentityCard(member: selectedMember, history: history),
        ],
        const SizedBox(height: AppSpacing.lg),
        AttendanceHistorySummaryCard(
          summary: history.summary,
          showMemberCount: selectedMemberId == null,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onCopyCsv,
          icon: const Icon(Icons.table_view_outlined, size: AppIconSize.sm),
          label: Text(
            history.isEmpty ? 'No rows to copy' : 'Copy CSV for spreadsheet',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (history.isEmpty)
          _EmptyReport(
            selectedName: selectedMemberId == null
                ? null
                : selectedMember?.fullName ?? selectedName,
          )
        else ...[
          for (final group in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                DateFormat('EEEE, d MMMM yyyy').format(group.key),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.slate500,
                ),
              ),
            ),
            for (final entry in group.value) ...[
              AttendanceRecordCard(
                entry: entry,
                showEmployee: selectedMemberId == null,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Open sessions are shown as unresolved and are not included in the '
          'hours total. No record is not treated as an absence.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.preset,
    required this.customFrom,
    required this.customTo,
    required this.rangeLabel,
    required this.selectedName,
    required this.hasMemberFilter,
    required this.onPresetSelected,
    required this.onPickMember,
  });

  final AttendanceReportRangePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String rangeLabel;
  final String selectedName;
  final bool hasMemberFilter;
  final ValueChanged<AttendanceReportRangePreset> onPresetSelected;
  final VoidCallback onPickMember;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Date range', style: textTheme.titleSmall)),
              Text(
                rangeLabel,
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in AttendanceReportRangePreset.values)
                _PeriodChip(
                  label: option == AttendanceReportRangePreset.custom
                      ? 'Custom'
                      : option.label,
                  selected: preset == option,
                  onSelected: () => onPresetSelected(option),
                ),
            ],
          ),
          if (preset == AttendanceReportRangePreset.custom &&
              customFrom != null &&
              customTo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Showing ${DateFormat('d MMM yyyy').format(customFrom!)} to '
              '${DateFormat('d MMM yyyy').format(customTo!)}.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
          const Divider(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      selectedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: hasMemberFilter ? onPickMember : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, TouchTarget.minInteractive),
                ),
                icon: const Icon(
                  Icons.filter_alt_outlined,
                  size: AppIconSize.sm,
                ),
                label: const Text('Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.emerald600,
      backgroundColor: AppColors.emerald50,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? AppColors.surface : AppColors.emerald700,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      onSelected: (_) => onSelected(),
    );
  }
}

class _MemberIdentityCard extends StatelessWidget {
  const _MemberIdentityCard({required this.member, required this.history});

  final AttendanceHistoryMember member;
  final AttendanceHistory history;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    AttendanceHistoryEntry? todayEntry;
    for (final entry in history.sessions) {
      if (isSameCalendarDay(entry.workDate, history.today)) {
        todayEntry = entry;
        break;
      }
    }
    final todayLabel = switch (todayEntry) {
      null => null,
      final entry when entry.isOpen =>
        'Today: checked in at ${entry.checkInTime}'
            '${entry.isLate ? ' (late)' : ''}',
      final entry =>
        'Today: completed at ${entry.checkOutTime ?? '--:--'}'
            '${entry.isLate ? ' (late)' : ''}',
    };
    final initials = _initials(member.fullName);

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.emerald50,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.emerald700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    MemberStatusChip(status: member.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  member.employeeCode ?? 'No staff code',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                    letterSpacing: .5,
                  ),
                ),
                if (todayLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    todayLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: todayEntry!.isLate || todayEntry.isOpen
                          ? AppColors.amber600
                          : AppColors.emerald700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _MemberPickerSheet extends StatelessWidget {
  const _MemberPickerSheet({
    required this.members,
    required this.selectedId,
    required this.allValue,
  });

  final List<AttendanceHistoryMember> members;
  final String? selectedId;
  final String allValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter by employee', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose one employee or view the whole team.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MemberOption(
              label: 'All employees',
              subtitle:
                  '${members.length} team '
                  '${members.length == 1 ? 'member' : 'members'}',
              selected: selectedId == null,
              onTap: () => Navigator.of(context).pop(allValue),
              leadingIcon: Icons.groups_outlined,
            ),
            for (final member in members) ...[
              const SizedBox(height: AppSpacing.sm),
              _MemberOption(
                label: member.fullName,
                subtitle: member.employeeCode ?? 'No staff code',
                selected: selectedId == member.id,
                onTap: () => Navigator.of(context).pop(member.id),
                leadingIcon: member.status == MemberStatus.active
                    ? Icons.person_outline_rounded
                    : Icons.person_off_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberOption extends StatelessWidget {
  const _MemberOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.leadingIcon,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? AppColors.emerald50 : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.emerald600 : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(leadingIcon, color: AppColors.emerald700),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emerald600,
                  size: AppIconSize.md,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({this.selectedName});

  final String? selectedName;

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
            selectedName == null
                ? 'No attendance in this period'
                : 'No attendance for $selectedName in this period',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try another date range or employee. No record is not counted as '
            'an absence.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}

String _rangeLabel(DateTime from, DateTime to) {
  if (isSameCalendarDay(from, to)) {
    return DateFormat('d MMM yyyy').format(from);
  }
  if (from.year == to.year && from.month == to.month) {
    return '${from.day}-${to.day} ${DateFormat('MMM yyyy').format(to)}';
  }
  if (from.year == to.year) {
    return '${DateFormat('d MMM').format(from)} - '
        '${DateFormat('d MMM yyyy').format(to)}';
  }
  return '${DateFormat('d MMM yyyy').format(from)} - '
      '${DateFormat('d MMM yyyy').format(to)}';
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
