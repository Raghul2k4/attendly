import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';

/// Change events from the auth provider, mapped to a plain [User?].
typedef AuthChange = User?;

/// Sign-up result: `needsEmailVerification` is true when account creation
/// succeeded but no session was issued (email confirmation enabled).
class SignUpOutcome {
  const SignUpOutcome({
    required this.user,
    required this.needsEmailVerification,
  });
  final User? user;
  final bool needsEmailVerification;
}

/// Storage-independent auth data source. Screens/controller depend on this
/// abstraction so widget tests can drive real flows with a fake.
abstract class AuthRepository {
  Future<User?> signIn({required String email, required String password});
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<User?> currentUser();
  Stream<AuthChange> get authChanges;
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    } catch (error, st) {
      Error.throwWithStackTrace(mapAuthError(error), st);
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return SignUpOutcome(
        user: res.user,
        needsEmailVerification: res.session == null && res.user != null,
      );
    } catch (error, st) {
      Error.throwWithStackTrace(mapAuthError(error), st);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error, st) {
      Error.throwWithStackTrace(mapAuthError(error), st);
    }
  }

  /// Permanently deletes the signed-in account on the server, then clears the
  /// local session. The confirmation string is re-checked server-side: the
  /// dialog alone is not trusted.
  ///
  /// The auth user no longer exists after the RPC, so the local sign-out must
  /// not depend on a network round-trip (the default local scope just clears
  /// storage). Any RPC failure leaves the account and session untouched.
  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_my_account', params: {'p_confirm': 'DELETE'});
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
    try {
      await _client.auth.signOut();
    } catch (_) {
      // The identity is already gone; a failed local clear must not turn a
      // completed deletion into an error. The next launch has no valid user.
    }
  }

  @override
  Future<User?> currentUser() async => _client.auth.currentUser;
  @override
  Stream<AuthChange> get authChanges => _client.auth.onAuthStateChange
      .map((event) => event.session?.user)
      .distinct();
}

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);
