import 'package:attendance/features/attendance/domain/attendance_correction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceCorrection', () {
    test('parses a server correction with both times', () {
      final correction = AttendanceCorrection.fromJson({
        'id': 'correction-1',
        'session_id': 'session-1',
        'member_id': 'm-1',
        'member_name': 'Suresh',
        'employee_code': '73WD-VHEA',
        'work_date': '2026-10-19',
        'workplace_name': 'Main Shop',
        'original_check_out_at': '2026-10-19T12:12:00+00:00',
        'original_check_out_time': '17:42',
        'corrected_check_out_at': '2026-10-19T13:00:00+00:00',
        'corrected_check_out_time': '18:30',
        'reason': 'Owner confirmed the employee left at 18:30',
        'actor_user_id': 'owner-1',
        'actor_name': 'Raghul',
        'created_at': '2026-10-20T13:50:00+00:00',
        'created_at_local': '20 Oct 2026 19:20',
      });

      expect(correction.memberName, 'Suresh');
      expect(correction.employeeCode, '73WD-VHEA');
      expect(correction.workDate, DateTime(2026, 10, 19));
      expect(correction.changeLabel, '17:42 → 18:30');
      expect(correction.reason, 'Owner confirmed the employee left at 18:30');
      expect(correction.actorName, 'Raghul');
      expect(correction.createdAtLocal, '20 Oct 2026 19:20');
    });

    test('a missed punch-out is described without a previous time', () {
      final correction = AttendanceCorrection.fromJson({
        'id': 'correction-2',
        'session_id': 'session-2',
        'member_id': 'm-1',
        'member_name': 'Suresh',
        'work_date': '2026-10-19',
        'original_check_out_at': null,
        'original_check_out_time': null,
        'corrected_check_out_at': '2026-10-19T13:00:00+00:00',
        'corrected_check_out_time': '18:30',
        'reason': 'Owner confirmed the employee left at 18:30',
        'created_at': '2026-10-20T13:50:00+00:00',
      });

      expect(correction.changeLabel, 'No check-out → 18:30');
      expect(correction.originalCheckOutAt, isNull);
    });

    test('a record without timestamps is rejected instead of guessed', () {
      expect(
        () => AttendanceCorrection.fromJson({
          'id': 'correction-3',
          'session_id': 'session-3',
          'work_date': '2026-10-19',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AttendanceCorrectionResult', () {
    test('parses the confirmed correction from the server', () {
      final result = AttendanceCorrectionResult.fromJson({
        'correction_id': 'correction-1',
        'session_id': 'session-1',
        'member_id': 'm-1',
        'member_name': 'Suresh',
        'employee_code': '73WD-VHEA',
        'work_date': '2026-10-19',
        'timezone': 'Asia/Kolkata',
        'original_check_out_at': null,
        'corrected_check_out_at': '2026-10-19T13:00:00+00:00',
        'corrected_check_out_time': '18:30',
        'duration_seconds': 34200,
        'corrected_at': '2026-10-20T13:50:00+00:00',
      });

      expect(result.correctedCheckOutTime, '18:30');
      expect(result.timezone, 'Asia/Kolkata');
      expect(result.duration, const Duration(hours: 9, minutes: 30));
      expect(result.memberName, 'Suresh');
    });
  });
}
