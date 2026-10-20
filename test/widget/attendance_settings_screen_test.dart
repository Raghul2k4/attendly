import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/attendance/presentation/attendance_settings_screen.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_fixtures.dart';
import '../support/fake_attendance_settings_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('AttendanceSettingsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeAttendanceSettingsRepository repository, {
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
            attendanceSettingsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AttendanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('loads the real policy and schedule from the server', (
      tester,
    ) async {
      final repository = FakeAttendanceSettingsRepository(
        settings: testAttendanceSettings(graceMinutes: 10),
      );
      await pumpScreen(tester, repository);

      expect(repository.fetchCalls, 1);
      expect(find.text('App button'), findsOneWidget);
      expect(find.text('Workplace QR code'), findsOneWidget);
      expect(find.text('Working days'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Maximum GPS inaccuracy'), findsOneWidget);
      expect(find.textContaining('50 metres'), findsWidgets);
      expect(
        find.textContaining('Readings weaker than this are rejected'),
        findsOneWidget,
      );
    });

    testWidgets('saves QR, Saturday and grace changes exactly once', (
      tester,
    ) async {
      final repository = FakeAttendanceSettingsRepository();
      await pumpScreen(tester, repository);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Workplace QR code'),
      );
      await tester.pump();
      final saturday = find.widgetWithText(FilterChip, 'Sat');
      await tester.ensureVisible(saturday);
      await tester.pumpAndSettle();
      await tester.tap(saturday);
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Save attendance rules'), 300);
      await tester.tap(find.text('Save attendance rules'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.lastAppPunchEnabled, isTrue);
      expect(repository.lastQrPunchEnabled, isTrue);
      expect(repository.lastWorkingDays, {1, 2, 3, 4, 5, 6});
      expect(repository.lastStartTime, '09:00');
      expect(repository.lastGraceMinutes, 10);
      expect(repository.lastMaxAccuracyMeters, 50);
      expect(
        find.text('Attendance rules saved. They apply to the next punch.'),
        findsOneWidget,
      );
    });

    testWidgets('cannot disable both punch methods', (tester) async {
      final repository = FakeAttendanceSettingsRepository();
      await pumpScreen(tester, repository);

      await tester.tap(find.widgetWithText(SwitchListTile, 'App button'));
      await tester.pump();

      expect(
        find.text(
          'Enable at least one method so employees can record attendance.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Save attendance rules'), 300);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save attendance rules'),
      );
      expect(button.onPressed, isNull);
      expect(repository.updateCalls, 0);
    });

    testWidgets('cannot remove every working day', (tester) async {
      final repository = FakeAttendanceSettingsRepository();
      await pumpScreen(tester, repository);

      for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
        final chip = find.widgetWithText(FilterChip, day);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pump();
      }

      await tester.ensureVisible(find.text('Choose at least one working day.'));
      expect(find.text('Choose at least one working day.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Save attendance rules'), 300);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save attendance rules'),
      );
      expect(button.onPressed, isNull);
      expect(repository.updateCalls, 0);
    });

    testWidgets('save failure keeps edits and offers retry', (tester) async {
      final repository = FakeAttendanceSettingsRepository(
        updateError: const AppException(
          'You don’t have permission to change these rules.',
          kind: AppErrorKind.permission,
        ),
      );
      await pumpScreen(tester, repository);

      await tester.scrollUntilVisible(find.text('Save attendance rules'), 300);
      await tester.tap(find.text('Save attendance rules'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(
        find.text('You don’t have permission to change these rules.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text('Attendance rules saved. They apply to the next punch.'),
        findsNothing,
      );
    });

    testWidgets('employees do not see owner controls', (tester) async {
      final repository = FakeAttendanceSettingsRepository();
      await pumpScreen(tester, repository, owner: false);

      expect(
        find.text('Only the business owner can change attendance rules.'),
        findsOneWidget,
      );
      expect(find.text('Save attendance rules'), findsNothing);
      expect(repository.fetchCalls, 0);
    });
  });
}
