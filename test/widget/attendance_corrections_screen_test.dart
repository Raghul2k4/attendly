import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/presentation/attendance_corrections_screen.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_correction_fixtures.dart';
import '../support/fake_attendance_correction_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('AttendanceCorrectionsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeAttendanceCorrectionRepository repository, {
      bool owner = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAccountProvider.overrideWith(
              (ref) async => owner ? testOwnerAccount() : testEmployeeAccount(),
            ),
            attendanceCorrectionRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AttendanceCorrectionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists every correction with its reason and actor', (
      tester,
    ) async {
      final repository = FakeAttendanceCorrectionRepository(
        corrections: [
          testCorrection(),
          testCorrection(
            id: 'correction-2',
            sessionId: 'session-2',
            memberName: 'Rahul Verma',
            employeeCode: 'JKMN-PQRS',
            originalCheckOutTime: null,
            correctedCheckOutTime: '17:05',
            reason: 'Employee left early, owner confirmed',
            createdAtLocal: '19 Oct 2026 20:02',
          ),
        ],
      );

      await pumpScreen(tester, repository);

      expect(repository.listCalls, 1);
      expect(find.text('Corrections'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Check-out 17:42 → 18:30'), findsOneWidget);
      expect(
        find.text('Owner confirmed the employee left at 18:30'),
        findsOneWidget,
      );
      expect(
        find.textContaining('by Raghul · 20 Oct 2026 19:20'),
        findsOneWidget,
      );
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Check-out No check-out → 17:05'), findsOneWidget);
      expect(find.text('Main Shop'), findsNWidgets(2));
    });

    testWidgets('an empty history explains what corrections are', (
      tester,
    ) async {
      await pumpScreen(tester, FakeAttendanceCorrectionRepository());

      expect(find.text('No corrections yet'), findsOneWidget);
      expect(
        find.textContaining('Nothing has been changed by hand'),
        findsOneWidget,
      );
    });

    testWidgets('a load failure is recoverable', (tester) async {
      final repository = FakeAttendanceCorrectionRepository(
        error: const AppException(
          'The corrections could not be loaded.',
          kind: AppErrorKind.server,
        ),
      );

      await pumpScreen(tester, repository);

      expect(find.text('The corrections could not be loaded.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('employees cannot review corrections', (tester) async {
      await pumpScreen(
        tester,
        FakeAttendanceCorrectionRepository(),
        owner: false,
      );

      expect(
        find.text('Only the business owner can review corrections.'),
        findsOneWidget,
      );
    });
  });
}
