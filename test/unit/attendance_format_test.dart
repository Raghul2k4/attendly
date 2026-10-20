import 'package:attendance/features/attendance/domain/attendance_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_fixtures.dart';

void main() {
  group('duration formatting', () {
    test('elapsed keeps hours and minutes', () {
      expect(
        formatElapsed(const Duration(hours: 2, minutes: 14, seconds: 9)),
        '2h 14m',
      );
      expect(formatElapsed(const Duration(minutes: 14)), '14m');
      expect(formatElapsed(Duration.zero), 'Less than a minute');
    });

    test('worked duration includes zero minutes', () {
      expect(formatWorked(const Duration(hours: 8, minutes: 52)), '8h 52m');
      expect(formatWorked(Duration.zero), '0m');
    });

    test('live timer is zero-padded', () {
      expect(
        formatTimer(const Duration(hours: 2, minutes: 4, seconds: 8)),
        '02:04:08',
      );
      expect(formatTimer(const Duration(minutes: 4, seconds: 8)), '04:08');
    });

    test('distance is readable in metres and kilometres', () {
      expect(formatDistance(320.6), '321 m');
      expect(formatDistance(1111.9), '1.1 km');
      expect(formatDistance(null), 'an unknown distance');
    });
  });

  group('rejection copy', () {
    test('outside geofence names the workplace and both distances', () {
      final result = testPunchResult(
        accepted: false,
        rejectionReason: 'outside_geofence',
        distanceMeters: 320,
        workplace: testAttendanceWorkplace(radiusMeters: 100),
      );
      final copy = attendanceRejectionCopy(result);

      expect(copy.title, 'Outside the workplace area');
      expect(copy.message, contains('about 320 m from Main Shop'));
      expect(copy.message, contains('permitted radius is 100 m'));
    });

    test('weak accuracy includes the server threshold', () {
      final result = testPunchResult(
        accepted: false,
        rejectionReason: 'location_accuracy_too_low',
        accuracyMeters: 75,
      );
      final copy = attendanceRejectionCopy(result, maxAccuracyMeters: 50);

      expect(copy.title, 'Location is too imprecise');
      expect(copy.message, contains('±75 m'));
      expect(copy.message, contains('limit is 50 m'));
    });

    test('invalid QR explains the replacement path', () {
      final result = testPunchResult(
        accepted: false,
        rejectionReason: 'invalid_qr',
      );
      final copy = attendanceRejectionCopy(result);

      expect(copy.title, 'QR code not accepted');
      expect(copy.message, contains('current code'));
    });

    test('accepted messages quote the server times', () {
      final inResult = testPunchResult(
        session: testAttendanceSession(checkInTime: '09:12'),
      );
      final outResult = testPunchResult(
        eventType: 'punch_out',
        session: testAttendanceSession(
          checkInTime: '09:12',
          checkOutTime: '17:42',
          checkOutAt: DateTime.now().toUtc(),
        ),
      );

      expect(acceptedPunchTitle(inResult), 'Checked in');
      expect(
        acceptedPunchMessage(inResult),
        'Your check-in was recorded at 09:12.',
      );
      expect(acceptedPunchTitle(outResult), 'Checked out');
      expect(acceptedPunchMessage(outResult), contains('at 17:42'));
    });
  });
}
