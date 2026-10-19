import 'package:attendance/app/app.dart';
import 'package:attendance/features/auth/data/auth_repository.dart'
    show authRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

void main() {
  group('WelcomeScreen', () {
    Future<FakeAuthRepository> pumpApp(WidgetTester tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: const AttendanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('offers two balanced role paths', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);

      expect(find.text('I own a business'), findsOneWidget);
      expect(find.text('I am an employee'), findsOneWidget);

      // Cards must be touch-friendly with meaningful labels (a11y).
      // The merged button node's label starts with the role title (the
      // card's body text is appended in the merged node).
      expect(
        find.bySemanticsLabel(RegExp(r'^I own a business')),
        findsOneWidget,
        reason: 'role cards expose button semantics with a meaningful label',
      );
      semantics.dispose();
    });

    testWidgets('owner path opens owner sign-up', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('I own a business'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(
        find.text('Create an account to set up your organisation.'),
        findsOneWidget,
      );
    });

    testWidgets('employee path opens sign-in first', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('I am an employee'));
      await tester.pumpAndSettle();

      expect(
        find.text('Welcome back. Use the email you registered with.'),
        findsOneWidget,
      );
    });
  });
}
