import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/device/punch_lockout.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/core/location/location_service.dart';
import 'package:attendance/features/attendance/domain/attendance_models.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/attendance/presentation/employee_home_view.dart';
import 'package:attendance/features/attendance/presentation/qr_scan_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_fixtures.dart';
import '../support/fake_attendance_repository.dart';
import '../support/fake_location_service.dart';
import '../support/fake_qr_scan_launcher.dart';
import '../support/organisation_fixtures.dart';

class FakePunchLockoutStore implements PunchLockoutStore {
  const FakePunchLockoutStore({this.lockedUntil});

  final DateTime? lockedUntil;

  @override
  Future<DateTime?> lockUntilFor(String userId) async => lockedUntil;

  @override
  Future<DateTime?> recordSignIn({
    required String userId,
    required DateTime at,
  }) async => null;
}

Future<void> pumpFrames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> pumpHome(
  WidgetTester tester, {
  required FakeAttendanceRepository repository,
  FakeLocationService? location,
  FakeQrScanLauncher? scanner,
  PunchLockoutStore? lockoutStore,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(repository),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        qrScanLauncherProvider.overrideWithValue(
          scanner ?? FakeQrScanLauncher(),
        ),
        punchLockoutStoreProvider.overrideWithValue(
          lockoutStore ?? const FakePunchLockoutStore(),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: EmployeeHomeView(account: testEmployeeAccount())),
      ),
    ),
  );
  await pumpFrames(tester);
}

void main() {
  group('EmployeeHomeView', () {
    testWidgets('shows identity, server state and one punch-in action', (
      tester,
    ) async {
      await pumpHome(tester, repository: FakeAttendanceRepository());

      expect(find.text('Hi, Priya'), findsOneWidget);
      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('Ready when you are.'), findsOneWidget);
      expect(find.text('Main Shop · 100 m radius'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Punch in'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Punch out'), findsNothing);
      expect(find.text('No attendance recorded yet today.'), findsOneWidget);
    });

    testWidgets('checked-in state shows live duration and punch out only', (
      tester,
    ) async {
      final session = testAttendanceSession(
        checkInAt: DateTime.now().toUtc().subtract(
          const Duration(hours: 1, minutes: 15, seconds: 5),
        ),
        checkInTime: '09:12',
      );
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          today: testAttendanceToday(
            state: AttendanceDayState.checkedIn,
            session: session,
          ),
        ),
      );

      expect(find.text('CHECKED IN'), findsOneWidget);
      expect(find.textContaining('01:15:'), findsOneWidget);
      expect(find.text('Since 09:12'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Punch out'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Punch in'), findsNothing);
    });

    testWidgets('late classification comes from the stored server state', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          today: testAttendanceToday(
            state: AttendanceDayState.checkedIn,
            session: testAttendanceSession(isLate: true),
          ),
        ),
      );

      expect(find.text('LATE ARRIVAL'), findsOneWidget);
      expect(find.text('CHECKED IN'), findsOneWidget);
    });

    testWidgets('completed state shows server times, duration and no action', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      final session = testAttendanceSession(
        checkInAt: now.subtract(const Duration(hours: 9)),
        checkOutAt: now.subtract(const Duration(minutes: 30)),
        checkInTime: '08:45',
        checkOutTime: '17:15',
      );
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          today: testAttendanceToday(
            state: AttendanceDayState.completed,
            session: session,
          ),
        ),
      );

      expect(find.text('DAY COMPLETE'), findsOneWidget);
      expect(find.text('8h 30m'), findsNWidgets(2));
      expect(find.text('17:15'), findsOneWidget);
      expect(find.text('Today’s attendance is complete.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('outside-geofence rejection is specific and not a success', (
      tester,
    ) async {
      final repository = FakeAttendanceRepository(
        punchResult: testPunchResult(
          accepted: false,
          rejectionReason: 'outside_geofence',
          distanceMeters: 320,
          workplace: testAttendanceWorkplace(radiusMeters: 100),
        ),
      );
      final location = FakeLocationService();
      await pumpHome(tester, repository: repository, location: location);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Punch in'));
      await pumpFrames(tester);

      expect(find.text('Outside the workplace area'), findsOneWidget);
      expect(find.textContaining('about 320 m from Main Shop'), findsOneWidget);
      expect(find.textContaining('permitted radius is 100 m'), findsOneWidget);
      expect(find.textContaining('Your check-in was recorded'), findsNothing);
      expect(repository.punchCalls, 1);
      expect(repository.lastAction, PunchAction.punchIn);
      expect(repository.lastMethod, PunchMethod.app);
      expect(repository.lastWorkplaceId, 'wp-1');
      expect(repository.lastLatitude, 12.971599);
      expect(repository.idempotencyKeys.single, isNotEmpty);
      expect(location.calls, 1);
    });

    testWidgets(
      'accepted punch shows confirmation and refreshes to punch out',
      (tester) async {
        final session = testAttendanceSession(checkInTime: '09:12');
        final repository = FakeAttendanceRepository(
          punchResult: testPunchResult(session: session),
          nextTodayAfterPunch: testAttendanceToday(
            state: AttendanceDayState.checkedIn,
            session: session,
          ),
        );
        await pumpHome(tester, repository: repository);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Punch in'));
        await pumpFrames(tester);

        expect(
          find.text('Your check-in was recorded at 09:12.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Punch out'),
          findsOneWidget,
        );
        expect(find.widgetWithText(ElevatedButton, 'Punch in'), findsNothing);
        expect(repository.punchCalls, 1);
      },
    );

    testWidgets('location denial stops before calling the punch RPC', (
      tester,
    ) async {
      final repository = FakeAttendanceRepository();
      final location = FakeLocationService(
        error: const AppException(
          'Location permission is needed to verify attendance. Allow it and '
          'try again.',
          kind: AppErrorKind.permission,
        ),
      );
      await pumpHome(tester, repository: repository, location: location);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Punch in'));
      await pumpFrames(tester);

      expect(
        find.text(
          'Location permission is needed to verify attendance. Allow it and '
          'try again.',
        ),
        findsOneWidget,
      );
      expect(repository.punchCalls, 0);
      expect(location.calls, 1);
    });

    testWidgets(
      'app and QR policies show one primary action plus a scan path',
      (tester) async {
        await pumpHome(
          tester,
          repository: FakeAttendanceRepository(
            today: testAttendanceToday(
              settings: testAttendanceSettings(qrPunchEnabled: true),
            ),
          ),
        );

        expect(find.widgetWithText(ElevatedButton, 'Punch in'), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'Scan QR instead'),
          findsOneWidget,
        );
      },
    );

    testWidgets('QR-only policy makes scanning the primary action', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          today: testAttendanceToday(
            settings: testAttendanceSettings(
              appPunchEnabled: false,
              qrPunchEnabled: true,
            ),
          ),
        ),
      );

      expect(
        find.widgetWithText(ElevatedButton, 'Scan QR code'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Punch in'), findsNothing);
    });

    testWidgets(
      'a valid scan submits the QR method without a client workplace',
      (tester) async {
        final scanner = FakeQrScanLauncher(payload: testQrPayload);
        final repository = FakeAttendanceRepository(
          today: testAttendanceToday(
            settings: testAttendanceSettings(qrPunchEnabled: true),
          ),
          punchResult: testPunchResult(
            session: testAttendanceSession(checkInTime: '09:12'),
          ),
        );
        final location = FakeLocationService();
        await pumpHome(
          tester,
          repository: repository,
          location: location,
          scanner: scanner,
        );

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Scan QR instead'),
        );
        await pumpFrames(tester);

        expect(scanner.calls, 1);
        expect(repository.punchCalls, 1);
        expect(repository.lastMethod, PunchMethod.qr);
        expect(
          repository.lastQrPayload,
          'attendance:workplace:v1:ABCD2EFGH3JKMN4PQRST',
        );
        expect(repository.lastWorkplaceId, isNull);
        expect(location.calls, 1);
        expect(
          find.text('Your check-in was recorded at 09:12.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unrelated QR codes are rejected before location or the server',
      (tester) async {
        final scanner = FakeQrScanLauncher(payload: 'https://example.com');
        final repository = FakeAttendanceRepository(
          today: testAttendanceToday(
            settings: testAttendanceSettings(qrPunchEnabled: true),
          ),
        );
        final location = FakeLocationService();
        await pumpHome(
          tester,
          repository: repository,
          location: location,
          scanner: scanner,
        );

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Scan QR instead'),
        );
        await pumpFrames(tester);

        expect(find.text('Not a workplace QR code'), findsOneWidget);
        expect(repository.punchCalls, 0);
        expect(location.calls, 0);
      },
    );

    testWidgets('scanner failure is recoverable and never records a punch', (
      tester,
    ) async {
      final scanner = FakeQrScanLauncher(error: Exception('camera busy'));
      final repository = FakeAttendanceRepository(
        today: testAttendanceToday(
          settings: testAttendanceSettings(qrPunchEnabled: true),
        ),
      );
      await pumpHome(tester, repository: repository, scanner: scanner);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Scan QR instead'));
      await pumpFrames(tester);

      expect(find.text('Scanner unavailable'), findsOneWidget);
      expect(find.text('Punch not recorded'), findsNothing);
      expect(repository.punchCalls, 0);
    });

    testWidgets('server QR rejection is specific and not a success', (
      tester,
    ) async {
      final scanner = FakeQrScanLauncher(payload: testQrPayload);
      final repository = FakeAttendanceRepository(
        today: testAttendanceToday(
          settings: testAttendanceSettings(qrPunchEnabled: true),
        ),
        punchResult: testPunchResult(
          accepted: false,
          rejectionReason: 'invalid_qr',
          distanceMeters: null,
        ),
      );
      await pumpHome(tester, repository: repository, scanner: scanner);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Scan QR instead'));
      await pumpFrames(tester);

      expect(find.text('QR code not accepted'), findsOneWidget);
      expect(find.textContaining('Your check-in was recorded'), findsNothing);
      expect(repository.lastMethod, PunchMethod.qr);
    });

    testWidgets('methods disabled shows guidance instead of a button', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          today: testAttendanceToday(
            settings: testAttendanceSettings(
              appPunchEnabled: false,
              qrPunchEnabled: false,
            ),
          ),
        ),
      );

      expect(
        find.textContaining('Your owner has turned off attendance methods'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('server load failure offers a retry instead of fake data', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: FakeAttendanceRepository(
          fetchError: const AppException(
            'You seem offline. Check your connection and try again.',
            kind: AppErrorKind.network,
          ),
        ),
      );

      expect(
        find.text('You seem offline. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Ready when you are.'), findsNothing);
    });
  });
}
