import 'attendance_history_models.dart';

enum AttendanceReportRangePreset {
  today,
  last7Days,
  thisMonth,
  lastMonth,
  custom,
}

extension AttendanceReportRangePresetLabel on AttendanceReportRangePreset {
  String get label => switch (this) {
    AttendanceReportRangePreset.today => 'Today',
    AttendanceReportRangePreset.last7Days => '7 days',
    AttendanceReportRangePreset.thisMonth => 'This month',
    AttendanceReportRangePreset.lastMonth => 'Last month',
    AttendanceReportRangePreset.custom => 'Custom',
  };
}

class AttendanceDateRange {
  const AttendanceDateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is AttendanceDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Organisation-local date ranges for the owner report. [today] must be the
/// server-provided work date, not the device date.
AttendanceDateRange attendanceRangeForPreset(
  AttendanceReportRangePreset preset,
  DateTime today,
) {
  final end = dateOnly(today);
  return switch (preset) {
    AttendanceReportRangePreset.today => AttendanceDateRange(
      from: end,
      to: end,
    ),
    AttendanceReportRangePreset.last7Days => AttendanceDateRange(
      from: addCalendarDays(end, -6),
      to: end,
    ),
    AttendanceReportRangePreset.thisMonth => AttendanceDateRange(
      from: firstDayOfMonth(end),
      to: end,
    ),
    AttendanceReportRangePreset.lastMonth => AttendanceDateRange(
      from: firstDayOfMonthOffset(end, -1),
      to: lastDayOfMonthOffset(end, -1),
    ),
    AttendanceReportRangePreset.custom => throw ArgumentError(
      'Custom ranges are selected explicitly.',
    ),
  };
}

/// The whole month containing [anchor], used by the employee month navigator.
AttendanceDateRange wholeMonthRange(DateTime anchor) => AttendanceDateRange(
  from: firstDayOfMonth(anchor),
  to: lastDayOfMonth(anchor),
);

bool isMonthAtOrAfter(DateTime anchor, DateTime today) =>
    firstDayOfMonth(anchor).isAfter(firstDayOfMonth(today)) ||
    firstDayOfMonth(anchor).isAtSameMomentAs(firstDayOfMonth(today));
