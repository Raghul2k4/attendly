import 'package:attendance/features/attendance/domain/attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceToday.fromJson', () {
    test('maps a checked-in server state without recomputing times', () {
      final today = AttendanceToday.fromJson({
        'server_time': '2026-10-20T00:02:02.318271+00:00',
        'work_date': '2026-10-20',
        'timezone': 'Asia/Kolkata',
        'state': 'checked_in',
        'session': {
          'id': 'session-1',
          'work_date': '2026-10-20',
          'check_in_at': '2026-10-20T03:32:03.125233+00:00',
          'check_out_at': null,
          'check_in_time': '09:02',
          'check_out_time': null,
        },
        'workplace': {'id': 'wp-1', 'name': 'Main Shop', 'radius_meters': 100},
        'settings': {
          'app_punch_enabled': true,
          'qr_punch_enabled': false,
          'max_accuracy_meters': 50,
          'start_time': '09:00',
          'grace_minutes': 10,
          'working_days': [1, 2, 3, 4, 5],
        },
      });

      expect(today.state, AttendanceDayState.checkedIn);
      expect(today.hasOpenSession, isTrue);
      expect(today.session?.checkInTime, '09:02');
      expect(today.session?.checkInAt.isUtc, isTrue);
      expect(today.session?.isOpen, isTrue);
      expect(today.workplace?.name, 'Main Shop');
      expect(today.workplace?.radiusMeters, 100);
      expect(today.settings.appPunchEnabled, isTrue);
      expect(today.settings.qrPunchEnabled, isFalse);
      expect(today.settings.workingDays, {1, 2, 3, 4, 5});
      expect(today.nextAction, PunchAction.punchOut);
    });

    test('completed state has no next action', () {
      final today = AttendanceToday.fromJson({
        'server_time': '2026-10-20T12:00:00+00:00',
        'work_date': '2026-10-20',
        'timezone': 'Asia/Kolkata',
        'state': 'completed',
        'session': {
          'id': 'session-1',
          'work_date': '2026-10-20',
          'check_in_at': '2026-10-20T03:30:00+00:00',
          'check_out_at': '2026-10-20T12:00:00+00:00',
          'check_in_time': '09:00',
          'check_out_time': '17:30',
        },
        'workplace': null,
        'settings': {
          'app_punch_enabled': true,
          'qr_punch_enabled': true,
          'max_accuracy_meters': 50,
          'start_time': '09:00',
          'grace_minutes': 10,
          'working_days': [1, 2, 3, 4, 5],
        },
      });

      expect(today.state, AttendanceDayState.completed);
      expect(today.nextAction, isNull);
      expect(today.session?.worked, const Duration(hours: 8, minutes: 30));
      expect(today.workplace, isNull);
    });

    test('no enabled method means no next action', () {
      final today = AttendanceToday.fromJson({
        'server_time': '2026-10-20T12:00:00+00:00',
        'work_date': '2026-10-20',
        'timezone': 'UTC',
        'state': 'not_started',
        'session': null,
        'workplace': null,
        'settings': {
          'app_punch_enabled': false,
          'qr_punch_enabled': false,
          'max_accuracy_meters': 50,
          'start_time': '09:00',
          'grace_minutes': 10,
          'working_days': [1, 2, 3, 4, 5],
        },
      });

      expect(today.state, AttendanceDayState.notStarted);
      expect(today.nextAction, isNull);
    });
  });

  group('PunchResult.fromJson', () {
    test('rejected outside-geofence result keeps server evidence', () {
      final result = PunchResult.fromJson({
        'event_id': 'event-1',
        'event_type': 'punch_in',
        'method': 'app',
        'validation_result': 'rejected',
        'rejection_reason': 'outside_geofence',
        'server_time': '2026-10-20T00:02:03+00:00',
        'accuracy_meters': 8,
        'distance_meters': 320.6,
        'workplace': {'id': 'wp-1', 'name': 'Main Shop', 'radius_meters': 100},
        'session': null,
      });

      expect(result.accepted, isFalse);
      expect(result.action, PunchAction.punchIn);
      expect(result.rejectionReason, 'outside_geofence');
      expect(result.distanceMeters, 320.6);
      expect(result.workplace?.radiusMeters, 100);
      expect(result.session, isNull);
    });

    test('accepted punch maps the confirmed session', () {
      final result = PunchResult.fromJson({
        'event_id': 'event-2',
        'event_type': 'punch_out',
        'method': 'app',
        'validation_result': 'accepted',
        'rejection_reason': null,
        'server_time': '2026-10-20T12:00:00+00:00',
        'accuracy_meters': 6,
        'distance_meters': 4.2,
        'workplace': {'id': 'wp-1', 'name': 'Main Shop', 'radius_meters': 100},
        'session': {
          'id': 'session-1',
          'work_date': '2026-10-20',
          'check_in_at': '2026-10-20T03:30:00+00:00',
          'check_out_at': '2026-10-20T12:00:00+00:00',
          'check_in_time': '09:00',
          'check_out_time': '17:30',
        },
      });

      expect(result.accepted, isTrue);
      expect(result.action, PunchAction.punchOut);
      expect(result.session?.isCompleted, isTrue);
      expect(result.session?.worked, const Duration(hours: 8, minutes: 30));
    });
  });
}
