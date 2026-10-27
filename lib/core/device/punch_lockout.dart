import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long a phone stays punch-locked after a different account signs in.
const punchLockoutWindow = Duration(hours: 1);

/// Pure rule: a sign-in starts a lock only when a *different* account had
/// already signed in on this phone. Re-authenticating the same employee
/// (session expiry, reinstall-free logout) never starts one, so normal use is
/// unaffected.
DateTime? lockStartForAccountSwitch({
  required String? previousUserId,
  required String userId,
  required DateTime at,
}) {
  if (previousUserId == null || previousUserId == userId) return null;
  return at.add(punchLockoutWindow);
}

/// Pure rule: the lock only applies to the account that triggered it and only
/// until it expires.
DateTime? activePunchLock({
  required String? lockedUserId,
  required String userId,
  required DateTime? lockedUntil,
  required DateTime now,
}) {
  if (lockedUserId == null || lockedUntil == null) return null;
  if (lockedUserId != userId) return null;
  return lockedUntil.isAfter(now) ? lockedUntil : null;
}

/// Device-local store for the anti-account-switching punch lock.
///
/// This is a deterrent, not a security boundary: reinstalling the app or
/// clearing app data removes it. The server still validates every punch
/// (identity, method, geofence, state), so a bypass cannot fabricate valid
/// attendance.
abstract class PunchLockoutStore {
  /// Returns the lock end time for [userId] if it is still in force.
  Future<DateTime?> lockUntilFor(String userId);

  /// Records a successful email/password sign-in. Returns the new lock end
  /// time when this sign-in switched accounts.
  Future<DateTime?> recordSignIn({
    required String userId,
    required DateTime at,
  });
}

class SharedPreferencesPunchLockoutStore implements PunchLockoutStore {
  const SharedPreferencesPunchLockoutStore();

  static const _lastUserKey = 'attendly.punch_lockout.last_user_id';
  static const _lockedUserKey = 'attendly.punch_lockout.locked_user_id';
  static const _lockedUntilKey = 'attendly.punch_lockout.locked_until';

  @override
  Future<DateTime?> lockUntilFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUntil = DateTime.tryParse(
      prefs.getString(_lockedUntilKey) ?? '',
    );
    return activePunchLock(
      lockedUserId: prefs.getString(_lockedUserKey),
      userId: userId,
      lockedUntil: storedUntil,
      now: DateTime.now(),
    );
  }

  @override
  Future<DateTime?> recordSignIn({
    required String userId,
    required DateTime at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString(_lastUserKey);
    await prefs.setString(_lastUserKey, userId);

    final until = lockStartForAccountSwitch(
      previousUserId: previousUserId,
      userId: userId,
      at: at,
    );
    if (until != null) {
      await prefs.setString(_lockedUserKey, userId);
      await prefs.setString(_lockedUntilKey, until.toUtc().toIso8601String());
      return until;
    }

    // A lock already in force for this account must survive signing out and
    // back in; only account switching creates one, but nothing short of the
    // clock clears an existing one.
    final existing = DateTime.tryParse(prefs.getString(_lockedUntilKey) ?? '');
    return activePunchLock(
      lockedUserId: prefs.getString(_lockedUserKey),
      userId: userId,
      lockedUntil: existing,
      now: at,
    );
  }
}

final punchLockoutStoreProvider = Provider<PunchLockoutStore>(
  (ref) => const SharedPreferencesPunchLockoutStore(),
);

/// Resolves the current lock for one account. Device-storage failures must not
/// block attendance with a fabricated lock, so they resolve to "no lock"; the
/// server remains the authority on whether a punch is valid.
final punchLockUntilProvider = FutureProvider.autoDispose
    .family<DateTime?, String>((ref, userId) async {
      try {
        return await ref.watch(punchLockoutStoreProvider).lockUntilFor(userId);
      } catch (_) {
        return null;
      }
    });
