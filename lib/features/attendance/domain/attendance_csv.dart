import 'attendance_history_models.dart';

/// Builds a spreadsheet-safe CSV from server-provided attendance records.
///
/// Every cell is quoted and every user-controlled value is neutralised if it
/// could be interpreted as a formula by Excel, LibreOffice or Google Sheets.
/// Numeric durations are exported in whole minutes so totals remain sortable.
String buildAttendanceCsv(
  List<AttendanceHistoryEntry> entries, {
  required String timezone,
}) {
  const headers = [
    'Date',
    'Employee',
    'Staff code',
    'Workplace',
    'Check-in',
    'Check-out',
    'Worked minutes',
    'Status',
    'Late',
    'Overnight',
    'Timezone',
  ];

  final lines = <String>[headers.map(_csvCell).join(',')];
  for (final entry in entries) {
    final status = entry.isStaleOpen
        ? 'Open from a previous day'
        : entry.isOpen
        ? 'Still checked in'
        : entry.isLate
        ? 'Late'
        : 'Completed';
    lines.add(
      [
        entry.workDate.toIso8601String().split('T').first,
        entry.memberName,
        entry.employeeCode ?? '',
        entry.workplaceName,
        entry.checkInTime,
        entry.checkOutTime ?? '',
        entry.isOpen ? '' : (entry.duration?.inMinutes.toString() ?? ''),
        status,
        entry.isLate ? 'Yes' : 'No',
        entry.crossesMidnight ? 'Yes' : 'No',
        timezone,
      ].map(_csvCell).join(','),
    );
  }
  return '${lines.join('\r\n')}\r\n';
}

String _csvCell(String value) {
  final sanitised = _neutraliseFormula(value);
  return '"${sanitised.replaceAll('"', '""')}"';
}

/// A leading formula marker makes spreadsheet software evaluate a cell. Prefix
/// an apostrophe so the value is displayed as text, including when whitespace
/// precedes the marker.
String _neutraliseFormula(String value) {
  final probe = value.replaceFirst(RegExp(r'^\s+'), '');
  if (probe.isNotEmpty && '=+-@\t\r'.contains(probe[0])) {
    return "'$value";
  }
  return value;
}
