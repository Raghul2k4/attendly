import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/auth/data/auth_repository.dart'
    show SignUpOutcome, authRepositoryProvider;
import 'package:attendance/features/auth/presentation/sign_up_screen.dart';
import 'package:attendance/features/onboarding/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/field_finders.dart';

void main() {
  group('SignUpScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeAuthRepository fake, {
      UserRole role = UserRole.owner,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp(home: SignUpScreen(role: role)),
        ),
      );
    }

    Finder submitButton() =>
        find.widgetWithText(ElevatedButton, 'Create account');

    Future<void> fillForm(
      WidgetTester tester, {
      String name = 'Ada Pullin',
      String email = 'ada@cafe.example.com',
      String password = 'biology-9-latitude',
    }) async {
      await tester.enterText(labeledField('Full name'), name);
      await tester.enterText(labeledField('Email'), email);
      await tester.enterText(labeledField('Password'), password);
      await tester.pump();
    }

    testWidgets('shows owner copy for owner role', (tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake, role: UserRole.owner);
      expect(
        find.text('Create an account to set up your organisation.'),
        findsOneWidget,
      );
    });

    testWidgets('shows employee copy for employee role', (tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake, role: UserRole.employee);
      expect(
        find.text(
          'Create an account, then enter the staff code from your owner.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('validation blocks empty fields', (tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake);

      await tester.tap(submitButton());
      await tester.pump();

      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(fake.signUpCalls, 0);
    });

    testWidgets('short password is rejected with length guidance', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake);
      await fillForm(tester, password: 'short');

      await tester.pump();
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(fake.signUpCalls, 0);
    });

    testWidgets('failed sign-up renders inline error', (tester) async {
      final fake = FakeAuthRepository(
        signUpException: const AppException(
          'An account with this email already exists. Try signing in instead.',
          kind: AppErrorKind.conflict,
        ),
      );
      await pumpScreen(tester, fake);
      await fillForm(tester);

      await tester.tap(submitButton());
      await tester.pump();

      expect(fake.signUpCalls, 1);
      expect(
        find.text(
          'An account with this email already exists. Try signing in instead.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('email-confirmation flow shows verification notice and keeps '
        'button disabled', (tester) async {
      final fake = FakeAuthRepository(
        signUpOutcome: const SignUpOutcome(
          user: null,
          needsEmailVerification: true,
        ),
      );
      await pumpScreen(tester, fake);
      await fillForm(tester);

      await tester.tap(submitButton());
      await tester.pump();

      expect(
        find.textContaining('Account created. Check your inbox'),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(fake.signUpCalls, 1);
    });
  });
}
