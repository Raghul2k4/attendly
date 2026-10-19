import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/organisation/presentation/join_organisation_screen.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_organisation_repository.dart';
import '../support/field_finders.dart';

void main() {
  group('JoinOrganisationScreen', () {
    Widget harness(FakeOrganisationRepository fake) {
      final router = GoRouter(
        initialLocation: '/setup/join',
        routes: [
          GoRoute(
            path: '/setup/join',
            builder: (_, _) => const JoinOrganisationScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME STUB')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [organisationRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );
    }

    testWidgets('rejects malformed tokens without calling the backend', (
      tester,
    ) async {
      final fake = FakeOrganisationRepository();
      await tester.pumpWidget(harness(fake));

      await tester.enterText(labeledField('Invite token'), 'ABC');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Join organisation'),
      );
      await tester.pump();

      expect(
        find.text(
          'Invite tokens are 20 characters. Check the code and try again.',
        ),
        findsOneWidget,
      );
      expect(fake.claimCalls, 0);
    });

    testWidgets('normalises a pasted token before claiming', (tester) async {
      final fake = FakeOrganisationRepository();
      await tester.pumpWidget(harness(fake));

      await tester.enterText(
        labeledField('Invite token'),
        'abcd-efgh-jkmn-pqrs-tuvw',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Join organisation'),
      );
      await tester.pumpAndSettle();

      expect(fake.claimCalls, 1);
      expect(fake.lastClaimToken, 'ABCDEFGHJKMNPQRSTUVW');
      expect(find.text('HOME STUB'), findsOneWidget);
    });

    testWidgets('shows the backend rejection and stays on the form', (
      tester,
    ) async {
      final fake = FakeOrganisationRepository(
        claimError: const AppException(
          'This invite token isn’t valid or was already used. Ask your owner '
          'for a new one.',
          kind: AppErrorKind.conflict,
        ),
      );
      await tester.pumpWidget(harness(fake));

      await tester.enterText(
        labeledField('Invite token'),
        'ABCD-EFGH-JKMN-PQRS-TUVW',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Join organisation'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('isn’t valid or was already used'),
        findsOneWidget,
      );
      expect(find.text('HOME STUB'), findsNothing);
    });
  });
}
