import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/organisation/presentation/create_organisation_screen.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_organisation_repository.dart';
import '../support/field_finders.dart';

void main() {
  group('CreateOrganisationScreen', () {
    Widget harness(FakeOrganisationRepository fake) {
      final router = GoRouter(
        initialLocation: '/setup/create-organisation',
        routes: [
          GoRoute(
            path: '/setup/create-organisation',
            builder: (_, _) => const CreateOrganisationScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME STUB')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          organisationRepositoryProvider.overrideWithValue(fake),
          deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Kolkata'),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );
    }

    testWidgets('validates the name before calling the backend', (
      tester,
    ) async {
      final fake = FakeOrganisationRepository();
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(find.text('Asia/Kolkata'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create business'));
      await tester.pump();

      expect(find.text('Enter your business name.'), findsOneWidget);
      expect(fake.createCalls, 0);
    });

    testWidgets('creates the organisation with the detected timezone', (
      tester,
    ) async {
      final fake = FakeOrganisationRepository();
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(labeledField('Business name'), 'Corner Cafe');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create business'));
      await tester.pumpAndSettle();

      expect(fake.createCalls, 1);
      expect(fake.lastCreateName, 'Corner Cafe');
      expect(fake.lastCreateTimezone, 'Asia/Kolkata');
      expect(find.text('HOME STUB'), findsOneWidget);
    });

    testWidgets('surfaces backend failures without navigating away', (
      tester,
    ) async {
      final fake = FakeOrganisationRepository(
        createError: const AppException(
          'We couldn’t create the organisation. Try again.',
          kind: AppErrorKind.server,
        ),
      );
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(labeledField('Business name'), 'Corner Cafe');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create business'));
      await tester.pumpAndSettle();

      expect(
        find.text('We couldn’t create the organisation. Try again.'),
        findsOneWidget,
      );
      expect(find.text('HOME STUB'), findsNothing);
    });
  });
}
