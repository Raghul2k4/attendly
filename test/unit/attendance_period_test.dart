import 'package:attendance/features/attendance/domain/attendance_history_models.dart';
import 'package:attendance/features/attendance/domain/attendance_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  group('attendanceRangeForPreset', () {
    test('today is a single organisation-local date', () {
      final range = attendanceRangeForPreset(
        AttendanceReportRangePreset.today,
        today,
      );
      expect(range.from, DateTime(2026, 10, 20));
      expect(range.to, DateTime(2026, 10, 20));
    });

    test('seven days includes today and six calendar days before it', () {
      final range = attendanceRangeForPreset(
        AttendanceReportRangePreset.last7Days,
        today,
      );
      expect(range.from, DateTime(2026, 10, 14));
      expect(range.to, today);
    });

    test('this month ends on the server-provided today', () {
      final range = attendanceRangeForPreset(
        AttendanceReportRangePreset.thisMonth,
        today,
      );
      expect(range.from, DateTime(2026, 10, 1));
      expect(range.to, today);
    });

    test('last month is the complete previous month', () {
      final range = attendanceRangeForPreset(
        AttendanceReportRangePreset.lastMonth,
        DateTime(2026, 1, 15),
      );
      expect(range.from, DateTime(2025, 12, 1));
      expect(range.to, DateTime(2025, 12, 31));
    });

    test('custom is selected explicitly, never derived', () {
      expect(
        () =>
            attendanceRangeForPreset(AttendanceReportRangePreset.custom, today),
        throwsArgumentError,
      );
    });
  });

  test('wholeMonthRange returns first and last day', () {
    final range = wholeMonthRange(DateTime(2026, 2, 14));
    expect(range.from, DateTime(2026, 2, 1));
    expect(range.to, DateTime(2026, 2, 28));
  });

  test('calendar-day arithmetic survives month and year boundaries', () {
    expect(addCalendarDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    expect(addCalendarDays(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
    expect(addCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
  });

  test('month comparison uses the month, not the day', () {
    expect(isMonthAtOrAfter(DateTime(2026, 10, 1), today), isTrue);
    expect(isMonthAtOrAfter(DateTime(2026, 10, 31), today), isTrue);
    expect(isMonthAtOrAfter(DateTime(2026, 9, 30), today), isFalse);
    expect(isMonthAtOrAfter(DateTime(2026, 11, 1), today), isTrue);
  });

  test('ISO date does not leak a time component', () {
    expect(isoDate(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
  });
}
