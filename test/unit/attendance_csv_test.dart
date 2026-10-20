import 'package:attendance/features/attendance/domain/attendance_csv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_history_fixtures.dart';

void main() {
  group('buildAttendanceCsv', () {
    test('exports quoted machine-readable rows with worked minutes', () {
      final csv = buildAttendanceCsv([
        testHistoryEntry(
          memberName: 'Priya Sharma',
          employeeCode: 'ABCD-EFGH',
          checkOutTime: '17:42',
          duration: const Duration(hours: 8, minutes: 30),
        ),
      ], timezone: 'Asia/Kolkata');

      expect(
        csv,
        startsWith(
          '"Date","Employee","Staff code","Workplace","Check-in",'
          '"Check-out","Worked minutes","Status","Late","Overnight","Timezone"\r\n',
        ),
      );
      expect(csv, contains('"2026-10-20","Priya Sharma","ABCD-EFGH"'));
      expect(csv, contains('"09:12","17:42","510","Completed","No","No"'));
      expect(csv, contains('"Asia/Kolkata"\r\n'));
    });

    test('open sessions leave the worked column blank and say why', () {
      final csv = buildAttendanceCsv([
        testHistoryEntry(isOpen: true, isStaleOpen: true, checkOutTime: null),
      ], timezone: 'Asia/Kolkata');

      expect(csv, contains('"09:12","","","Open from a previous day"'));
    });

    test('neutralises spreadsheet formulas in user-controlled fields', () {
      final csv = buildAttendanceCsv([
        testHistoryEntry(
          memberName: '=HYPERLINK("https://evil.test")',
          employeeCode: '+1-555-0100',
          workplaceName: '@Main Shop',
        ),
      ], timezone: 'Asia/Kolkata');

      expect(csv, contains('"\'=HYPERLINK(""https://evil.test"")"'));
      expect(csv, contains('"\'+1-555-0100"'));
      expect(csv, contains('"\'@Main Shop"'));
      expect(csv, isNot(contains(',"=HYPERLINK')));
    });

    test('neutralises formula markers hidden behind leading whitespace', () {
      final csv = buildAttendanceCsv([
        testHistoryEntry(memberName: '  =1+1'),
      ], timezone: 'UTC');

      expect(csv, contains('"\'  =1+1"'));
    });

    test('quotes commas, quotes and newlines without breaking rows', () {
      final csv = buildAttendanceCsv([
        testHistoryEntry(
          memberName: 'Ada "A", Manager',
          workplaceName: 'Shop\nAnnex',
        ),
      ], timezone: 'UTC');

      expect(csv, contains('"Ada ""A"", Manager"'));
      expect(csv, contains('"Shop\nAnnex"'));
    });

    test('empty history still returns a header', () {
      final csv = buildAttendanceCsv(const [], timezone: 'UTC');
      expect(csv.trim().split('\r\n'), hasLength(1));
      expect(csv, contains('"Worked minutes"'));
    });
  });
}
