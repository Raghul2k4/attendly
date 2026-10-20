import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../domain/attendance_correction_models.dart';
import '../../domain/attendance_history_models.dart';
import '../attendance_providers.dart';

/// Owner sheet for correcting a recorded check-out.
///
/// The owner picks the wall-clock date and time in the organisation timezone;
/// the server converts it, stores the previous value, writes an audit entry and
/// only then confirms. The client never claims success on its own.
class AttendanceCorrectionSheet extends ConsumerStatefulWidget {
  const AttendanceCorrectionSheet({
    super.key,
    required this.entry,
    required this.timezone,
    required this.today,
  });

  final AttendanceHistoryEntry entry;
  final String timezone;
  final DateTime today;

  static Future<AttendanceCorrectionResult?> show(
    BuildContext context, {
    required AttendanceHistoryEntry entry,
    required String timezone,
    required DateTime today,
  }) {
    return showModalBottomSheet<AttendanceCorrectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AttendanceCorrectionSheet(
        entry: entry,
        timezone: timezone,
        today: today,
      ),
    );
  }

  @override
  ConsumerState<AttendanceCorrectionSheet> createState() =>
      _AttendanceCorrectionSheetState();
}

class _AttendanceCorrectionSheetState
    extends ConsumerState<AttendanceCorrectionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  bool _submitting = false;
  AppException? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.entry.workDate;
    final recorded = widget.entry.checkOutTime;
    _time = _parseTime(recorded) ?? const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime get _lastPickableDate {
    final nextDay = DateTime(
      widget.entry.workDate.year,
      widget.entry.workDate.month,
      widget.entry.workDate.day + 1,
    );
    if (nextDay.isAfter(widget.today)) {
      return widget.today.isBefore(widget.entry.workDate)
          ? widget.entry.workDate
          : widget.today;
    }
    return nextDay;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.entry.workDate,
      lastDate: _lastPickableDate,
      helpText: 'Check-out date',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Check-out time',
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(attendanceCorrectionRepositoryProvider)
          .correctCheckOut(
            sessionId: widget.entry.id,
            date: _date,
            time: _timeLabel,
            reason: _reasonController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = mapBackendError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text('Correct check-out', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${widget.entry.memberName} · '
                '${DateFormat('EEEE, d MMMM').format(widget.entry.workDate)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PickerRow(
                label: 'Check-out date',
                value: DateFormat('EEE, d MMM yyyy').format(_date),
                onTap: _submitting ? null : _pickDate,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PickerRow(
                label: 'Check-out time',
                value: _timeLabel,
                onTap: _submitting ? null : _pickTime,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Reason',
                controller: _reasonController,
                validator: Validators.correctionReason,
                enabled: !_submitting,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Times are saved in ${widget.timezone}. The original punch '
                'record is kept and the change is added to the audit trail.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppErrorPanel(
                  message: _error!.message,
                  kind: _error!.kind,
                  onRetry: _submit,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'Save correction',
                onPressed: _submit,
                inProgress: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(value, style: textTheme.bodyLarge),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                size: AppIconSize.md,
                color: AppColors.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
