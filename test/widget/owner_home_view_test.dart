import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/attendance/domain/attendance_history_models.dart';
import 'package:attendance/features/attendance/presentation/attendance_providers.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:attendance/features/organisation/presentation/owner_home_view.dart';
import 'package:attendance/features/workplaces/presentation/workplace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_history_fixtures.dart';
import '../support/fake_attendance_history_repository.dart';
import '../support/fake_attendance_settings_repository.dart';
import '../support/fake_organisation_repository.dart';
import '../support/fake_workplace_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('OwnerHomeView', () {
    Future<void> pumpView(
      WidgetTester tester, {
      required MyAccount account,
      required List<Membership> members,
      FakeAttendanceHistoryRepository? historyRepository,
    }) async {
      tester.view.physicalSize = const Size(1080, 5400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fake = FakeOrganisationRepository(
        account: account,
        members: members,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organisationRepositoryProvider.overrideWithValue(fake),
            workplaceRepositoryProvider.overrideWithValue(
              FakeWorkplaceRepository(),
            ),
            attendanceSettingsRepositoryProvider.overrideWithValue(
              FakeAttendanceSettingsRepository(),
            ),
            attendanceHistoryRepositoryProvider.overrideWithValue(
              historyRepository ?? FakeAttendanceHistoryRepository(),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: OwnerHomeView(account: account)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows real seat usage and the staff roster', (tester) async {
      final owner = testOwnerAccount();
      final members = [
        owner.membership,
        testMember(id: 'm-2', fullName: 'Priya Sharma'),
        testMember(
          id: 'm-3',
          fullName: 'Rahul Verma',
          employeeCode: 'JKMN-PQRS',
        ),
        testMember(
          id: 'm-4',
          fullName: 'Neha Kapoor',
          status: MemberStatus.invited,
          employeeCode: 'TUVW-XYZ2',
        ),
      ];

      await pumpView(tester, account: owner, members: members);

      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('2 of 15 used'), findsOneWidget);
      expect(find.textContaining('1 invite is waiting'), findsOneWidget);
      expect(find.text('Add staff'), findsOneWidget);
      expect(find.text('Ada Owner'), findsOneWidget);
      expect(find.text('Business owner'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Neha Kapoor'), findsOneWidget);
      expect(find.text('Invite sent'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Checked in'), findsOneWidget);
      expect(find.text('No record yet'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsNWidgets(2));
      expect(find.text('Checked in now'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Attendance report'), findsOneWidget);
    });

    testWidgets('surfaces prior open sessions and live overview failures', (
      tester,
    ) async {
      final account = testOwnerAccount();
      final overview = testOwnerOverview(
        lateTodayCount: 1,
        unresolvedPriorCount: 1,
        openSessions: [
          AttendanceOpenSession(
            memberId: 'm-2',
            memberName: 'Suresh Kumar',
            employeeCode: 'WXYZ-2345',
            checkInTime: '09:05',
            workDate: DateTime(2026, 10, 19),
            isLate: true,
            isStaleOpen: true,
          ),
        ],
        recentSessions: [
          testHistoryEntry(
            memberId: 'm-2',
            memberName: 'Suresh Kumar',
            employeeCode: 'WXYZ-2345',
            workDate: DateTime(2026, 10, 19),
            isOpen: true,
            isStaleOpen: true,
            isLate: true,
            checkOutTime: null,
          ),
        ],
      );

      await pumpView(
        tester,
        account: account,
        members: [
          account.membership,
          testMember(id: 'm-2'),
        ],
        historyRepository: FakeAttendanceHistoryRepository(overview: overview),
      );

      expect(
        find.textContaining('One session is still open from a previous day'),
        findsOneWidget,
      );
      expect(find.text('Since 19 Oct, 09:05'), findsOneWidget);
      expect(find.text('19 Oct - In 09:12, still checked in'), findsOneWidget);
      expect(find.text('Late'), findsWidgets);
    });

    testWidgets('an overview failure leaves the rest of the dashboard usable', (
      tester,
    ) async {
      final account = testOwnerAccount();
      await pumpView(
        tester,
        account: account,
        members: [
          account.membership,
          testMember(id: 'm-2'),
        ],
        historyRepository: FakeAttendanceHistoryRepository(
          overviewError: const AppException(
            'Live attendance is unavailable right now.',
            kind: AppErrorKind.network,
          ),
        ),
      );

      expect(
        find.text('Live attendance is unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Add staff'), findsOneWidget);
    });

    testWidgets('empty team shows a useful next step', (tester) async {
      final account = testOwnerAccount();

      await pumpView(tester, account: account, members: [account.membership]);

      expect(find.text('0 of 15 used'), findsOneWidget);
      expect(find.text('No employees yet'), findsOneWidget);
      expect(find.text('Add staff'), findsOneWidget);
      expect(find.text('Workplaces'), findsOneWidget);
      expect(find.text('Attendance rules'), findsOneWidget);
      expect(
        find.text('Add your first location and check-in radius'),
        findsOneWidget,
      );
      expect(find.textContaining('App button'), findsOneWidget);
    });
  });
}
