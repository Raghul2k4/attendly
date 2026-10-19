import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/auth/data/auth_repository.dart'
    show authRepositoryProvider;
import 'package:attendance/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/field_finders.dart';
import '../support/fake_auth_repository.dart';

void main() {
  group('SignInScreen', () {
    Future<void> pumpScreen(WidgetTester tester, FakeAuthRepository fake) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
    }

    Finder submitButton() => find.widgetWithText(ElevatedButton, 'Sign in');

    testWidgets('empty submission surfaces inline validation', (tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake);

      await tester.tap(submitButton());
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(fake.signInCalls, 0);
      expect(find.text('Your email or password is incorrect.'), findsNothing);
    });

    testWidgets('recoverable auth failure renders inline error panel', (
      tester,
    ) async {
      final fake = FakeAuthRepository(
        signInException: const AppException(
          'Your email or password is incorrect.',
          kind: AppErrorKind.auth,
        ),
      );
      await pumpScreen(tester, fake);

      await tester.enterText(labeledField('Email'), 'owner@example.com');
      await tester.enterText(labeledField('Password'), 'correct-horse');
      await tester.tap(submitButton());
      await tester.pump();

      expect(fake.signInCalls, 1);
      expect(find.text('Your email or password is incorrect.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets(
      'network failure shows offline copy, not "something went wrong"',
      (tester) async {
        final fake = FakeAuthRepository(
          signInException: const AppException(
            'You seem offline. Check your connection and try again.',
            kind: AppErrorKind.network,
          ),
        );
        await pumpScreen(tester, fake);

        await tester.enterText(labeledField('Email'), 'owner@example.com');
        await tester.enterText(labeledField('Password'), 'correct-horse');
        await tester.tap(submitButton());
        await tester.pump();

        expect(
          find.text('You seem offline. Check your connection and try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('in-flight button ignores duplicate taps', (tester) async {
      final fake = FakeAuthRepository()..pendingSignIn = true;
      await pumpScreen(tester, fake);

      await tester.enterText(labeledField('Email'), 'owner@example.com');
      await tester.enterText(labeledField('Password'), 'correct-horse');

      await tester.tap(submitButton());
      await tester.pump(); // enter in-flight state (button stays labeled)

      // Duplicate tap must not start another request.
      await tester.tap(submitButton());
      await tester.pump();

      expect(fake.signInCalls, 1);

      fake.releaseSignIn(null);
      await tester.pump();
    });

    testWidgets('password field masks input with a toggle', (tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, fake);

      await tester.enterText(labeledField('Password'), 'hunter2hunter2');
      // The password field is the last instantiated TextField on screen and
      // starts masked.
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isFalse,
      );
    });
  });
}
