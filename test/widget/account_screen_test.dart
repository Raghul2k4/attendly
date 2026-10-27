import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/features/auth/data/auth_repository.dart'
    show authRepositoryProvider;
import 'package:attendance/features/auth/presentation/account_screen.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show organisationRepositoryProvider;
import 'package:attendance/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_organisation_repository.dart';
import '../support/organisation_fixtures.dart';

User _user({String email = 'ada@example.com'}) => User.fromJson({
  'id': 'u-owner',
  'email': email,
  'user_metadata': {'full_name': 'Ada Owner'},
})!;

Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byIcon(Icons.delete_outline_rounded),
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.delete_outline_rounded));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeOrganisationRepository organisations,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        organisationRepositoryProvider.overrideWithValue(organisations),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const AccountScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AccountScreen', () {
    testWidgets('shows the signed-in identity and the business', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      expect(find.text('Ada Owner'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Asia/Kolkata'), findsOneWidget);
      expect(find.text('Free · Unlimited staff'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
    });

    testWidgets('an employee sees their staff code and paused status', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testEmployeeAccount(fullName: 'Priya Sharma'),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('sign out goes through the auth repository', (tester) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
    });

    testWidgets('the privacy policy opens inside the app', (tester) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Who runs this app'), findsOneWidget);
      expect(find.text('What we store'), findsOneWidget);
    });

    testWidgets('deletion is blocked until DELETE is typed', (tester) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await _openDeleteDialog(tester);

      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Corner Cafe'),
        ),
        findsOneWidget,
      );

      final confirmButton = find.widgetWithText(FilledButton, 'Delete account');
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'delete');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'DELETE');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    });

    testWidgets('a confirmed deletion calls the server and closes', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await _openDeleteDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(auth.deleteAccountCalls, 1);
      expect(find.text('Delete account?'), findsNothing);
    });

    testWidgets('an employee warning states that records are retained', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initialUser: _user());
      final organisations = FakeOrganisationRepository(
        account: testEmployeeAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await _openDeleteDialog(tester);

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('keeps its attendance records'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a server failure keeps the dialog open with the reason', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        initialUser: _user(),
        deleteAccountException: const AppException(
          'Type DELETE exactly to confirm account deletion.',
          kind: AppErrorKind.invalidInput,
        ),
      );
      final organisations = FakeOrganisationRepository(
        account: testOwnerAccount(),
      );
      await _pump(tester, auth: auth, organisations: organisations);

      await _openDeleteDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.text('Type DELETE exactly to confirm account deletion.'),
        findsOneWidget,
      );
      expect(auth.deleteAccountCalls, 1);
    });
  });
}
