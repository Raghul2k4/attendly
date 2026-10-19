import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:attendance/features/organisation/presentation/owner_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_organisation_repository.dart';
import '../support/organisation_fixtures.dart';

void main() {
  group('OwnerHomeView', () {
    Future<void> pumpView(
      WidgetTester tester, {
      required MyAccount account,
      required List<Membership> members,
    }) async {
      final fake = FakeOrganisationRepository(
        account: account,
        members: members,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [organisationRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: OwnerHomeView(account: account)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows real seat usage and the staff roster', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
    });

    testWidgets('empty team shows a useful next step', (tester) async {
      final account = testOwnerAccount();

      await pumpView(tester, account: account, members: [account.membership]);

      expect(find.text('0 of 15 used'), findsOneWidget);
      expect(find.text('No employees yet'), findsOneWidget);
      expect(find.text('Add staff'), findsOneWidget);
    });
  });
}
