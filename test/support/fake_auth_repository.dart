import 'dart:async';

import 'package:attendance/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic AuthRepository fake for widget/controller tests: tests
/// script each method and control the auth-change stream explicitly.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.initialUser,
    this.signInException,
    this.signInResult,
    this.signUpException,
    this.signUpOutcome,
    this.signOutException,
    this.deleteAccountException,
  });

  final User? initialUser;
  final Exception? signInException;
  final User? signInResult;
  final Exception? signUpException;
  final SignUpOutcome? signUpOutcome;
  final Exception? signOutException;
  final Exception? deleteAccountException;

  final _signInGate = <Completer<User?>>[];

  /// When true, `signIn()` returns a future the test controls via
  /// [releaseSignIn] — for exercising in-flight states without timing luck.
  bool pendingSignIn = false;

  final StreamController<AuthChange> _changes = StreamController.broadcast();
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int deleteAccountCalls = 0;

  bool get hasListeners => _changes.hasListener;

  void emitChange(User? user) => _changes.add(user);

  void releaseSignIn(User? user) {
    for (final completer in List.of(_signInGate)) {
      completer.complete(
        user ?? _user('user-signin', email: 'owner@example.com'),
      );
      _signInGate.remove(completer);
    }
  }

  User? _user(String id, {String? email, Map<String, dynamic>? metadata}) =>
      User.fromJson({
        'id': id,
        'email': email,
        'user_metadata': metadata ?? {},
      });

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInException != null) throw signInException!;
    if (pendingSignIn) {
      final gate = Completer<User?>();
      _signInGate.add(gate);
      return gate.future.then((user) {
        emitChange(user);
        return user;
      });
    }
    final result = signInResult ?? _user('user-signin', email: email);
    emitChange(result);
    return result;
  }

  @override
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (signUpException != null) throw signUpException!;
    final outcome =
        signUpOutcome ??
        SignUpOutcome(
          user: _user(
            'user-signup',
            email: email,
            metadata: {'full_name': fullName},
          ),
          needsEmailVerification: false,
        );
    if (outcome.user != null) emitChange(outcome.user!);
    return outcome;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutException != null) throw signOutException!;
    emitChange(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    if (deleteAccountException != null) throw deleteAccountException!;
    emitChange(null);
  }

  @override
  Future<User?> currentUser() async => initialUser;

  @override
  Stream<AuthChange> get authChanges => _changes.stream;
}
