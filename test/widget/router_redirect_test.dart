import 'package:attendance/app/app.dart';
import 'package:attendance/features/auth/data/auth_repository.dart'
    show authRepositoryProvider;
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_organisation_repository.dart';

void main() {
  group('app routing around auth state', () {
    testWidgets(
      'starts at welcome, reaches home on session, returns on sign out',
      (tester) async {
        final fake = FakeAuthRepository();
        final organisations = FakeOrganisationRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fake),
              organisationRepositoryProvider.overrideWithValue(organisations),
            ],
            child: const AttendanceApp(),
          ),
        );
        // No real user: bootstrap resolves to signed-out.
        await tester.pumpAndSettle();

        expect(find.text('I own a business'), findsOneWidget);
        expect(find.text('I am an employee'), findsOneWidget);

        // Session arrives (e.g. persisted session restored).
        final user = User.fromJson({
          'id': 'u-1',
          'user_metadata': {'full_name': 'Ada'},
        });
        fake.emitChange(user);
        await tester.pumpAndSettle();

        // Signed in without a membership: the gate offers setup paths.
        expect(find.text('Hi, Ada'), findsOneWidget);
        expect(find.text('Create a business'), findsOneWidget);
        expect(find.text('Join with an invite token'), findsOneWidget);

        // Explicit sign out lives in Account and returns to the public area.
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();

        expect(find.text('Privacy policy'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(fake.signOutCalls, 1);
        expect(find.text('I own a business'), findsOneWidget);
      },
    );

    testWidgets('protected area is off-limits while signed out', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      final organisations = FakeOrganisationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fake),
            organisationRepositoryProvider.overrideWithValue(organisations),
          ],
          child: const AttendanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Guards redirect unknown/signed-out to public area, never home.
      expect(find.text('I own a business'), findsOneWidget);
      expect(find.text('Create a business'), findsNothing);
      expect(organisations.fetchAccountCalls, 0);
    });
  });
}
