import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../data/auth_repository.dart';

export '../data/auth_repository.dart' show SignUpOutcome;

/// Router-level auth status. Only three states exist at this granularity;
/// finer states (form busy, verification notice) are screen concerns.
enum AuthStatus { unknown, signedOut, signedIn }

/// Single source of truth for "is anyone signed in?".
class AuthState {
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.signedOut() : this._(AuthStatus.signedOut, null);
  const AuthState.signedIn(User user) : this._(AuthStatus.signedIn, user);

  final AuthStatus status;
  final User? user;

  bool get isUnknown => status == AuthStatus.unknown;
  bool get isSignedOut => status == AuthStatus.signedOut;
  bool get isSignedIn => status == AuthStatus.signedIn;
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<AuthChange>? _changesSub;

  @override
  AuthState build() {
    _listenToRepository();

    Future.microtask(() async {
      final user = await ref.read(authRepositoryProvider).currentUser();
      if (!_disposed) {
        state = user != null ? AuthState.signedIn(user) : AuthState.signedOut();
      }
    });
    return const AuthState.unknown();
  }

  bool _disposed = false;

  void _listenToRepository() {
    final repo = ref.read(authRepositoryProvider);
    _changesSub = repo.authChanges.listen(
      (user) {
        if (!_disposed) {
          state = user != null
              ? AuthState.signedIn(user)
              : AuthState.signedOut();
        }
      },
      onError: (Object error) {
        if (!_disposed) {
          // A broken stream shouldn't brick the app; surface a signedOut
          // state with a generic mapping at next action, not at startup.
          state = const AuthState.signedOut();
        }
      },
    );
    ref.onDispose(() {
      _disposed = true;
      _changesSub?.cancel();
    });
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Runs the actual sign-in/sign-up/sign-out calls, mapping failures so the
/// form layer deals only in [AppException]s.
class AuthActions {
  AuthActions(this._repository);

  final AuthRepository _repository;

  Future<User?> signIn(String email, String password) async {
    try {
      return await _repository.signIn(email: email.trim(), password: password);
    } on AppException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      return await _repository.signUp(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AppException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } on AppException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    }
  }
}

final authActionsProvider = Provider<AuthActions>(
  (ref) => AuthActions(ref.watch(authRepositoryProvider)),
);
