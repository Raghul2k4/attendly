import 'package:attendance/features/auth/data/auth_repository.dart';
import 'package:attendance/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';

/// Controller-level auth stream behavior: bootstrap resolution and live
/// session changes drive the router through the same signals.
void main() {
  group('AuthController via repository stream', () {
    test('bootstrap resolves signedOut without a stored user', () async {
      final fake = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final statuses = <AuthStatus>[];
      container.listen<AuthState>(
        authControllerProvider,
        (previous, next) => statuses.add(next.status),
        fireImmediately: true,
      );

      // Let the bootstrap microtask run to completion.
      await Future<void>.delayed(Duration.zero);
      expect(statuses, [AuthStatus.unknown, AuthStatus.signedOut]);
    });

    test('sign-up success publishes the signed-in state', () async {
      final fake = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final statuses = <AuthStatus>[];
      container.listen<AuthState>(
        authControllerProvider,
        (previous, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      await container
          .read(authActionsProvider)
          .signUp(
            fullName: 'Ada Pullin',
            email: 'ada@cafe.example.com',
            password: 'biology-9-latitude',
          );
      expect(statuses.last, AuthStatus.signedIn);
      expect(fake.signUpCalls, 1);
    });

    test('sign-out returns to the signed-out state', () async {
      final fake = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final statuses = <AuthStatus>[];
      container.listen<AuthState>(
        authControllerProvider,
        (previous, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      await container
          .read(authActionsProvider)
          .signIn('ada@cafe.example.com', 'biology-9-latitude');
      expect(statuses.last, AuthStatus.signedIn);

      await container.read(authActionsProvider).signOut();
      expect(statuses.last, AuthStatus.signedOut);
      expect(fake.signOutCalls, 1);
    });
  });
}
