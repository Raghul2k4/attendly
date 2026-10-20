import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/domain/attendance_history_models.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/attendance/presentation/attendance_report_screen.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_correction_fixtures.dart';
import '../support/attendance_history_fixtures.dart';
import '../support/fake_attendance_correction_repository.dart';
import '../support/fake_attendance_history_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('AttendanceReportScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeAttendanceHistoryRepository repository, {
      String? initialMemberId,
      String? initialMemberName,
      bool owner = true,
      FakeAttendanceCorrectionRepository? correctionRepository,
    }) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAccountProvider.overrideWith(
              (ref) async => owner ? testOwnerAccount() : testEmployeeAccount(),
            ),
            attendanceHistoryRepositoryProvider.overrideWithValue(repository),
            attendanceCorrectionRepositoryProvider.overrideWithValue(
              correctionRepository ?? FakeAttendanceCorrectionRepository(),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: AttendanceReportScreen(
              initialMemberId: initialMemberId,
              initialMemberName: initialMemberName,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FakeAttendanceHistoryRepository echoingRepository({
      required List<AttendanceHistoryEntry> sessions,
      List<AttendanceHistoryMember>? members,
    }) => FakeAttendanceHistoryRepository(
      reportBuilder: (_, from, to, memberId) => testAttendanceHistory(
        from: from ?? testHistoryMonthStart,
        to: to ?? testHistoryToday,
        sessions: sessions
            .where((entry) => memberId == null || entry.memberId == memberId)
            .toList(growable: false),
        members: members,
      ),
    );

    testWidgets('shows the team summary and real records', (tester) async {
      final repository = echoingRepository(
        sessions: [
          testHistoryEntry(
            memberName: 'Priya Sharma',
            checkOutTime: '17:42',
            duration: const Duration(hours: 8, minutes: 30),
          ),
        ],
      );

      await pumpScreen(tester, repository);

      expect(repository.reportCalls, 1);
      expect(repository.reportQueries.single.from, isNull);
      expect(repository.reportQueries.single.to, isNull);
      expect(find.text('Attendance report'), findsOneWidget);
      expect(find.text('Period totals'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Copy CSV for spreadsheet'), findsOneWidget);
      expect(find.text('Tuesday, 20 October 2026'), findsOneWidget);
      expect(find.text('8h 30m'), findsWidgets);
    });

    testWidgets(
      'preset date filters are calculated from the server work date',
      (tester) async {
        final repository = echoingRepository(sessions: [testHistoryEntry()]);
        await pumpScreen(tester, repository);

        await tester.tap(find.widgetWithText(FilterChip, 'Today'));
        await tester.pumpAndSettle();

        expect(repository.reportQueries, hasLength(2));
        expect(repository.reportQueries.last.from, DateTime(2026, 10, 20));
        expect(repository.reportQueries.last.to, DateTime(2026, 10, 20));
        expect(find.text('20 Oct 2026'), findsOneWidget);
      },
    );

    testWidgets('filters the report to one employee', (tester) async {
      final repository = echoingRepository(
        sessions: [
          testHistoryEntry(memberName: 'Priya Sharma'),
          testHistoryEntry(
            id: 'session-2',
            memberId: 'm-2',
            memberName: 'Rahul Verma',
            employeeCode: 'JKMN-PQRS',
            workDate: DateTime(2026, 10, 19),
          ),
        ],
        members: [
          testHistoryMember(),
          testHistoryMember(
            id: 'm-2',
            fullName: 'Rahul Verma',
            employeeCode: 'JKMN-PQRS',
          ),
        ],
      );
      await pumpScreen(tester, repository);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filter'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Rahul Verma')),
      );
      await tester.pumpAndSettle();

      expect(repository.reportQueries.last.memberId, 'm-2');
      expect(find.text('Employee attendance'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsWidgets);
      expect(find.text('JKMN-PQRS'), findsWidgets);
      expect(find.text('Priya Sharma'), findsNothing);
    });

    testWidgets('can open directly on one employee from staff management', (
      tester,
    ) async {
      final repository = echoingRepository(sessions: [testHistoryEntry()]);
      await pumpScreen(
        tester,
        repository,
        initialMemberId: 'm-1',
        initialMemberName: 'Priya Sharma',
      );

      expect(repository.reportQueries.single.memberId, 'm-1');
      expect(find.text('Employee attendance'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsWidgets);
      expect(find.text('Today: completed at 17:42'), findsOneWidget);
    });

    testWidgets('empty reports disable CSV and avoid calling it an absence', (
      tester,
    ) async {
      final repository = FakeAttendanceHistoryRepository(
        report: testAttendanceHistory(sessions: const []),
      );
      await pumpScreen(tester, repository);

      expect(find.text('No attendance in this period'), findsOneWidget);
      expect(
        find.textContaining('No record is not counted as an absence'),
        findsOneWidget,
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'No rows to copy'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a report failure is recoverable', (tester) async {
      final repository = FakeAttendanceHistoryRepository(
        reportError: const AppException(
          'The report could not be loaded.',
          kind: AppErrorKind.server,
        ),
      );
      await pumpScreen(tester, repository);

      expect(find.text('The report could not be loaded.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('employees cannot open the team report', (tester) async {
      await pumpScreen(tester, FakeAttendanceHistoryRepository(), owner: false);

      expect(
        find.text('Only the business owner can view team reports.'),
        findsOneWidget,
      );
    });

    testWidgets('the owner can open the correction sheet for a record', (
      tester,
    ) async {
      final repository = echoingRepository(sessions: [testHistoryEntry()]);
      await pumpScreen(tester, repository);

      expect(find.text('Correct check-out'), findsOneWidget);
      await tester.tap(find.text('Correct check-out'));
      await tester.pumpAndSettle();

      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Check-out date'), findsOneWidget);
      expect(find.text('Save correction'), findsOneWidget);
    });

    testWidgets('a corrected record is labelled as corrected', (tester) async {
      final repository = echoingRepository(
        sessions: [testHistoryEntry(isCorrected: true)],
      );
      await pumpScreen(tester, repository);

      expect(find.text('Corrected'), findsOneWidget);
    });

    testWidgets('a saved correction refetches the report from the server', (
      tester,
    ) async {
      final repository = echoingRepository(sessions: [testHistoryEntry()]);
      final corrections = FakeAttendanceCorrectionRepository(
        result: testCorrectionResult(correctedCheckOutTime: '18:30'),
      );
      await pumpScreen(tester, repository, correctionRepository: corrections);
      expect(repository.reportCalls, 1);

      await tester.tap(find.text('Correct check-out'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Owner confirmed the employee left at 18:30',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(corrections.calls, hasLength(1));
      // The report must be re-read from the server, not left stale.
      expect(repository.reportCalls, 2);
      expect(find.text('Check-out corrected to 18:30.'), findsOneWidget);
    });
  });
}
