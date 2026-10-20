import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/presentation/attendance_history_screen.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_history_fixtures.dart';
import '../support/fake_attendance_history_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('AttendanceHistoryScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeAttendanceHistoryRepository repository, {
      bool employee = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAccountProvider.overrideWith(
              (ref) async =>
                  employee ? testEmployeeAccount() : testOwnerAccount(),
            ),
            attendanceHistoryRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AttendanceHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current month summary and server-formatted record', (
      tester,
    ) async {
      final repository = FakeAttendanceHistoryRepository(
        myHistory: testAttendanceHistory(
          sessions: [
            testHistoryEntry(
              checkInTime: '09:12',
              checkOutTime: '17:42',
              duration: const Duration(hours: 8, minutes: 30),
            ),
          ],
        ),
      );

      await pumpScreen(tester, repository);

      expect(repository.myHistoryCalls, 1);
      expect(repository.myHistoryQueries.single.from, isNull);
      expect(repository.myHistoryQueries.single.to, isNull);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Period totals'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(find.text('8h 30m'), findsNWidgets(2));
      expect(find.text('Tuesday, 20 October'), findsOneWidget);
      expect(find.text('09:12'), findsOneWidget);
      expect(find.text('17:42'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Main Shop'), findsOneWidget);
      expect(find.textContaining('Asia/Kolkata'), findsOneWidget);
    });

    testWidgets('moves back a month and requests the full month range', (
      tester,
    ) async {
      final repository = FakeAttendanceHistoryRepository(
        myHistoryBuilder: (_, from, to) => testAttendanceHistory(
          from: from ?? testHistoryMonthStart,
          to: to ?? testHistoryToday,
          sessions: [testHistoryEntry(workDate: DateTime(2026, 9, 18))],
        ),
      );
      await pumpScreen(tester, repository);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(repository.myHistoryQueries, hasLength(2));
      expect(repository.myHistoryQueries.last.from, DateTime(2026, 9, 1));
      expect(repository.myHistoryQueries.last.to, DateTime(2026, 9, 30));
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Friday, 18 September'), findsOneWidget);
    });

    testWidgets('open sessions are labelled and excluded from hours', (
      tester,
    ) async {
      final repository = FakeAttendanceHistoryRepository(
        myHistory: testAttendanceHistory(
          sessions: [
            testHistoryEntry(
              isOpen: true,
              checkOutTime: null,
              elapsed: const Duration(hours: 2, minutes: 5),
            ),
          ],
        ),
      );

      await pumpScreen(tester, repository);

      expect(find.text('Still checked in'), findsOneWidget);
      expect(find.text('Elapsed'), findsOneWidget);
      expect(find.text('2h 5m'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text('0m'), findsOneWidget);
      expect(
        find.textContaining('not included in the hours total'),
        findsOneWidget,
      );
    });

    testWidgets('an empty month explains what will appear here', (
      tester,
    ) async {
      final repository = FakeAttendanceHistoryRepository(
        myHistory: testAttendanceHistory(sessions: const []),
      );

      await pumpScreen(tester, repository);

      expect(find.text('No attendance records this month'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(find.text('0m'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('a load failure is recoverable', (tester) async {
      final repository = FakeAttendanceHistoryRepository(
        myHistoryError: const AppException(
          'Attendance history is unavailable right now.',
          kind: AppErrorKind.network,
        ),
      );

      await pumpScreen(tester, repository);

      expect(
        find.text('Attendance history is unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('owners do not get a personal employee history', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAttendanceHistoryRepository(),
        employee: false,
      );

      expect(
        find.text('Only active employees have a personal attendance history.'),
        findsOneWidget,
      );
    });
  });
}
