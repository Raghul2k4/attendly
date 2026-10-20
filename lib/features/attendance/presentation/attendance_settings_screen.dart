import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/surface_card.dart';
import '../../organisation/domain/organisation_models.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../domain/attendance_models.dart';
import 'attendance_providers.dart';

/// Owner screen for the effective attendance policy. Every value is read from
/// and written to the server; the punch function re-reads the policy so a
/// change takes effect on the next attempt, including on another device.
class AttendanceSettingsScreen extends ConsumerWidget {
  const AttendanceSettingsScreen({super.key});

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

        if (!account!.membership.isOwner) {
          return _shell(
            ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                AppErrorPanel(
                  message:
                      'Only the business owner can change attendance rules.',
                  kind: AppErrorKind.permission,
                  onRetry: () => ref.invalidate(myAccountProvider),
                ),
              ],
            ),
          );
        }

        final settingsAsync = ref.watch(
          attendanceSettingsProvider(organisation.id),
        );
        return _shell(
          settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                AppErrorPanel(
                  message: error is AppException
                      ? error.message
                      : 'We couldn’t load attendance rules. Try again.',
                  kind: error is AppException
                      ? error.kind
                      : AppErrorKind.unknown,
                  onRetry: () => ref.invalidate(
                    attendanceSettingsProvider(organisation.id),
                  ),
                ),
              ],
            ),
            data: (settings) => _SettingsForm(
              key: ValueKey(
                '${settings.appPunchEnabled}-${settings.qrPunchEnabled}-'
                '${settings.startTime}-${settings.graceMinutes}-'
                '${settings.maxAccuracyMeters}-'
                '${(settings.workingDays.toList()..sort()).join(',')}',
              ),
              organisation: organisation,
              initial: settings,
            ),
          ),
        );
      },
    );
  }

  Widget _shell(Widget child) => Scaffold(
    appBar: AppBar(title: const Text('Attendance rules')),
    body: SafeArea(top: false, child: child),
  );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({
    super.key,
    required this.organisation,
    required this.initial,
  });

  final Organisation organisation;
  final AttendanceSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  static const _dayLabels = [
    (1, 'Mon'),
    (2, 'Tue'),
    (3, 'Wed'),
    (4, 'Thu'),
    (5, 'Fri'),
    (6, 'Sat'),
    (7, 'Sun'),
  ];

  late bool _appPunchEnabled;
  late bool _qrPunchEnabled;
  late Set<int> _workingDays;
  late TimeOfDay _startTime;
  late int _graceMinutes;
  late int _maxAccuracyMeters;
  bool _saving = false;
  AppException? _saveError;

  @override
  void initState() {
    super.initState();
    _appPunchEnabled = widget.initial.appPunchEnabled;
    _qrPunchEnabled = widget.initial.qrPunchEnabled;
    _workingDays = {...widget.initial.workingDays};
    _startTime = _parseTime(widget.initial.startTime);
    _graceMinutes = widget.initial.graceMinutes;
    _maxAccuracyMeters = widget.initial.maxAccuracyMeters;
  }

  bool get _hasMethod => _appPunchEnabled || _qrPunchEnabled;
  bool get _hasWorkingDay => _workingDays.isNotEmpty;
  bool get _canSave => !_saving && _hasMethod && _hasWorkingDay;

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  String get _startValue => _formatTime(_startTime);

  String get _lateThresholdLabel {
    final total = _startTime.hour * 60 + _startTime.minute + _graceMinutes;
    final hour = (total ~/ 60) % 24;
    final minute = total % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Expected start time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final saved = await ref
          .read(attendanceSettingsRepositoryProvider)
          .update(
            organisationId: widget.organisation.id,
            appPunchEnabled: _appPunchEnabled,
            qrPunchEnabled: _qrPunchEnabled,
            maxAccuracyMeters: _maxAccuracyMeters,
            startTime: _startValue,
            graceMinutes: _graceMinutes,
            workingDays: _workingDays,
          );
      ref.invalidate(attendanceSettingsProvider(widget.organisation.id));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _appPunchEnabled = saved.appPunchEnabled;
        _qrPunchEnabled = saved.qrPunchEnabled;
        _workingDays = {...saved.workingDays};
        _startTime = _parseTime(saved.startTime);
        _graceMinutes = saved.graceMinutes;
        _maxAccuracyMeters = saved.maxAccuracyMeters;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance rules saved. They apply to the next punch.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = error is AppException
            ? error
            : const AppException(
                'We couldn’t save attendance rules. Try again.',
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accuracyOptions = {
      25,
      50,
      75,
      100,
      widget.initial.maxAccuracyMeters,
    }.toList()..sort();

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
          'Set how your team records attendance. The server checks these rules '
          'on every punch.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Punch methods'),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  value: _appPunchEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _appPunchEnabled = value),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  secondary: const _SectionIcon(icon: Icons.touch_app_outlined),
                  title: const Text('App button'),
                  subtitle: const Text(
                    'Employees tap Punch in or out from the home screen. '
                    'Location is checked by the server.',
                  ),
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.lg),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  value: _qrPunchEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _qrPunchEnabled = value),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  secondary: const _SectionIcon(
                    icon: Icons.qr_code_scanner_rounded,
                  ),
                  title: const Text('Workplace QR code'),
                  subtitle: const Text(
                    'Employees scan the printed code at the workplace. Location '
                    'is still required.',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_hasMethod) ...[
          const SizedBox(height: AppSpacing.md),
          const _Note(
            kind: _NoteKind.warning,
            icon: Icons.info_outline_rounded,
            message:
                'Enable at least one method so employees can record '
                'attendance.',
          ),
        ],
        if (_qrPunchEnabled) ...[
          const SizedBox(height: AppSpacing.md),
          const _Note(
            kind: _NoteKind.info,
            icon: Icons.qr_code_2_rounded,
            message:
                'Each workplace needs its own printed QR code. Generate or '
                'replace one from Workplaces. A revoked code stops working '
                'immediately.',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Work schedule'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: AppIconSize.sm,
                    color: AppColors.slate500,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Working days', style: textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Late arrivals are only marked on these days.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (day, label) in _dayLabels)
                    _WorkingDayChip(
                      label: label,
                      selected: _workingDays.contains(day),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _workingDays.add(day);
                              } else {
                                _workingDays.remove(day);
                              }
                            }),
                    ),
                ],
              ),
              if (!_hasWorkingDay) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose at least one working day.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.rose600,
                  ),
                ),
              ],
              const Divider(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expected start', style: textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Used with the grace period to mark late check-ins.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickStartTime,
                    icon: const Icon(
                      Icons.schedule_rounded,
                      size: AppIconSize.sm,
                    ),
                    label: Text(_startValue),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: Text('Grace period', style: textTheme.titleSmall),
                  ),
                  Text(
                    '$_graceMinutes min',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.emerald700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _graceMinutes.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                label: '$_graceMinutes min',
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _graceMinutes = value.round()),
              ),
              Text(
                'A check-in after $_lateThresholdLabel is marked late on the '
                'selected days.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Location accuracy'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _maxAccuracyMeters,
                decoration: const InputDecoration(
                  labelText: 'Maximum GPS inaccuracy',
                ),
                items: [
                  for (final metres in accuracyOptions)
                    DropdownMenuItem(
                      value: metres,
                      child: Text('$metres metres'),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _maxAccuracyMeters = value);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Readings weaker than this are rejected. 50 m is a good '
                'starting point in towns and offices.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_saveError != null) ...[
          AppErrorPanel(
            message: _saveError!.message,
            kind: _saveError!.kind,
            onRetry: _save,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppPrimaryButton(
          label: 'Save attendance rules',
          onPressed: _canSave ? _save : null,
          inProgress: _saving,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Changes apply to the next punch. Existing attendance records keep '
          'their original times and late status.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _WorkingDayChip extends StatelessWidget {
  const _WorkingDayChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

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
      onSelected: onSelected,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.emerald50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: AppColors.emerald700, size: AppIconSize.md),
    );
  }
}

enum _NoteKind { info, warning }

class _Note extends StatelessWidget {
  const _Note({required this.kind, required this.icon, required this.message});

  final _NoteKind kind;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final warning = kind == _NoteKind.warning;
    final background = warning ? AppColors.amber50 : AppColors.emerald50;
    final foreground = warning ? AppColors.amber600 : AppColors.emerald700;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.sm, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
