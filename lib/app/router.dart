import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/dashboard/presentation/account_home_screen.dart';
import '../features/onboarding/domain/user_role.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/splash/splash_screen.dart';

/// Bridges riverpod auth changes into go_router's refreshListenable.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final _authStateListenableProvider = Provider<AuthStateListenable>((ref) {
  final listenable = AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(_authStateListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) =>
        _redirect(state, ref.read(authControllerProvider)),
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (_, state) => SignUpScreen(
          role: state.extra is UserRole
              ? state.extra! as UserRole
              : UserRole.owner,
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'account-home',
        builder: (_, _) => const AccountHomeScreen(),
      ),
    ],
  );
});

/// Guards are declarative here:
///  unknown  → splash only (bootstrap hasn't resolved yet)
///  signedIn → everything funnels to home
///  signedOut→ public onboarding screens only; '/' bounces to welcome
String? _redirect(GoRouterState state, AuthState auth) {
  final location = state.matchedLocation;
  switch (auth.status) {
    case AuthStatus.unknown:
      return location == '/' ? null : '/';
    case AuthStatus.signedIn:
      return location == '/home' ? null : '/home';
    case AuthStatus.signedOut:
      final isPublic =
          location == '/welcome' ||
          location == '/sign-in' ||
          location == '/sign-up';
      return isPublic ? null : '/welcome';
  }
}
