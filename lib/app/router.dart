import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/attendance/presentation/attendance_corrections_screen.dart';
import '../features/attendance/presentation/attendance_history_screen.dart';
import '../features/attendance/presentation/attendance_report_screen.dart';
import '../features/attendance/presentation/attendance_settings_screen.dart';
import '../features/onboarding/domain/user_role.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/organisation/presentation/account_gate_screen.dart';
import '../features/organisation/presentation/create_organisation_screen.dart';
import '../features/organisation/presentation/join_organisation_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/workplaces/presentation/workplace_editor_screen.dart';
import '../features/workplaces/presentation/workplaces_screen.dart';

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
        name: 'home',
        builder: (_, _) => const AccountGateScreen(),
      ),
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (_, _) => const AccountScreen(),
      ),
      GoRoute(
        path: '/workplaces',
        name: 'workplaces',
        builder: (_, _) => const WorkplacesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-workplace',
            builder: (_, _) => const WorkplaceEditorScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'edit-workplace',
            builder: (_, state) =>
                WorkplaceEditorScreen(workplaceId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/attendance-settings',
        name: 'attendance-settings',
        builder: (_, _) => const AttendanceSettingsScreen(),
      ),
      GoRoute(
        path: '/attendance-history',
        name: 'attendance-history',
        builder: (_, _) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/attendance-report',
        name: 'attendance-report',
        builder: (_, state) => AttendanceReportScreen(
          initialMemberId: state.uri.queryParameters['member'],
          initialMemberName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/attendance-corrections',
        name: 'attendance-corrections',
        builder: (_, _) => const AttendanceCorrectionsScreen(),
      ),
      GoRoute(
        path: '/setup/create-organisation',
        name: 'create-organisation',
        builder: (_, _) => const CreateOrganisationScreen(),
      ),
      GoRoute(
        path: '/setup/join',
        name: 'join-organisation',
        builder: (_, _) => const JoinOrganisationScreen(),
      ),
    ],
  );
});

/// Guards are declarative here:
///  unknown  → splash only (bootstrap hasn't resolved yet)
///  signedIn → home plus the setup screens it can push
///  signedOut→ public onboarding screens only; '/' bounces to welcome
String? _redirect(GoRouterState state, AuthState auth) {
  final location = state.matchedLocation;
  switch (auth.status) {
    case AuthStatus.unknown:
      return location == '/' ? null : '/';
    case AuthStatus.signedIn:
      final isInsideApp =
          location == '/home' ||
          location.startsWith('/account') ||
          location.startsWith('/setup/') ||
          location.startsWith('/attendance-settings') ||
          location.startsWith('/attendance-history') ||
          location.startsWith('/attendance-report') ||
          location.startsWith('/attendance-corrections') ||
          location.startsWith('/workplaces');
      return isInsideApp ? null : '/home';
    case AuthStatus.signedOut:
      final isPublic =
          location == '/welcome' ||
          location == '/sign-in' ||
          location == '/sign-up';
      return isPublic ? null : '/welcome';
  }
}
