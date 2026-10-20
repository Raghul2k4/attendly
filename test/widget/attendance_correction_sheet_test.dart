import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/attendance/presentation/widgets/attendance_correction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_correction_fixtures.dart';
import '../support/attendance_history_fixtures.dart';
import '../support/fake_attendance_correction_repository.dart';

void main() {
  group('AttendanceCorrectionSheet', () {
    Future<FakeAttendanceCorrectionRepository> openSheet(
      WidgetTester tester, {
      FakeAttendanceCorrectionRepository? repository,
    }) async {
      final fake = repository ?? FakeAttendanceCorrectionRepository();
      tester.view.physicalSize = const Size(1080, 3900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceCorrectionRepositoryProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AttendanceCorrectionSheet.show(
                      context,
                      entry: testHistoryEntry(
                        workDate: DateTime(2026, 10, 19),
                        checkOutTime: '17:42',
                      ),
                      timezone: 'Asia/Kolkata',
                      today: DateTime(2026, 10, 20),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('shows the record context and the server timezone', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Correct check-out'), findsOneWidget);
      expect(find.textContaining('Priya Sharma'), findsOneWidget);
      expect(find.textContaining('Monday, 19 October'), findsOneWidget);
      expect(find.text('Check-out date'), findsOneWidget);
      expect(find.text('Check-out time'), findsOneWidget);
      expect(find.text('17:42'), findsOneWidget);
      expect(find.textContaining('Asia/Kolkata'), findsOneWidget);
      expect(
        find.textContaining('original punch record is kept'),
        findsOneWidget,
      );
    });

    testWidgets('a reason is required before anything is sent', (tester) async {
      final repository = await openSheet(tester);

      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(find.text('Add a reason for this correction.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('sends the wall-clock time and the reason to the server', (
      tester,
    ) async {
      final repository = await openSheet(tester);

      await tester.enterText(
        find.byType(TextFormField),
        'Owner confirmed the employee left at 18:30',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(1));
      final call = repository.calls.single;
      expect(call.sessionId, 'session-1');
      expect(call.date, DateTime(2026, 10, 19));
      expect(call.time, '17:42');
      expect(call.reason, 'Owner confirmed the employee left at 18:30');
      expect(find.text('Correct check-out'), findsNothing);
    });

    testWidgets('a rejected correction is explained and can be retried', (
      tester,
    ) async {
      final repository = await openSheet(
        tester,
        repository: FakeAttendanceCorrectionRepository(
          error: const AppException(
            'The check-out time can’t be in the future.',
            kind: AppErrorKind.invalidInput,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'Owner confirmed the employee left at 18:30',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(
        find.text('The check-out time can’t be in the future.'),
        findsOneWidget,
      );
      expect(find.text('Correct check-out'), findsOneWidget);
      expect(repository.calls, hasLength(1));

      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();
      expect(repository.calls, hasLength(2));
    });

    testWidgets('the confirmed result is what the server returned', (
      tester,
    ) async {
      await openSheet(
        tester,
        repository: FakeAttendanceCorrectionRepository(
          result: testCorrectionResult(correctedCheckOutTime: '19:05'),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'Owner confirmed the employee left at 19:05',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(find.text('Correct check-out'), findsNothing);
    });
  });
}
