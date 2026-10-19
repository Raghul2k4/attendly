import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:attendance/features/organisation/presentation/widgets/invite_staff_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_organisation_repository.dart';
import '../support/field_finders.dart';

void main() {
  group('InviteStaffSheet', () {
    testWidgets('issues a staff code and one-time token after inviting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fake = FakeOrganisationRepository(
        inviteResult: const InviteResult(
          memberId: 'm-9',
          employeeCode: 'ABCD-EFGH',
          inviteToken: 'ABCDEFGHJKMNPQRSTUVW',
          employeeName: 'Rahul Verma',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [organisationRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: InviteStaffSheet(
                organisationId: 'org-1',
                organisationName: 'Corner Cafe',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(labeledField('Employee name'), 'Rahul Verma');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create invite'));
      await tester.pumpAndSettle();

      expect(fake.inviteCalls, 1);
      expect(fake.lastInviteName, 'Rahul Verma');
      expect(find.text('Invite ready'), findsOneWidget);
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.text('ABCD-EFGH-JKMN-PQRS-TUVW'), findsOneWidget);
      expect(find.text('Copy invite details'), findsOneWidget);
    });

    testWidgets('validates the name before inviting', (tester) async {
      final fake = FakeOrganisationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [organisationRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: InviteStaffSheet(
                organisationId: 'org-1',
                organisationName: 'Corner Cafe',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create invite'));
      await tester.pump();

      expect(find.text('Enter the employee’s name.'), findsOneWidget);
      expect(fake.inviteCalls, 0);
    });
  });
}
