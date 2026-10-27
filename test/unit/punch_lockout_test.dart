import 'package:attendance/core/device/punch_lockout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PunchLockout', () {
    final now = DateTime(2026, 10, 27, 10, 0);

    test('same account sign-in never locks attendance', () {
      final lock = lockStartForAccountSwitch(
        previousUserId: 'user-1',
        userId: 'user-1',
        at: now,
      );
      expect(lock, isNull);
    });

    test('first sign-in on fresh device never locks attendance', () {
      final lock = lockStartForAccountSwitch(
        previousUserId: null,
        userId: 'user-1',
        at: now,
      );
      expect(lock, isNull);
    });

    test('switching accounts triggers a 1-hour lock for the new account', () {
      final lock = lockStartForAccountSwitch(
        previousUserId: 'user-1',
        userId: 'user-2',
        at: now,
      );
      expect(lock, now.add(const Duration(hours: 1)));
    });

    test('activePunchLock only applies to the locked user while before expiry', () {
      final expiry = now.add(const Duration(hours: 1));

      expect(
        activePunchLock(
          lockedUserId: 'user-2',
          userId: 'user-2',
          lockedUntil: expiry,
          now: now.add(const Duration(minutes: 30)),
        ),
        expiry,
      );

      expect(
        activePunchLock(
          lockedUserId: 'user-2',
          userId: 'user-1',
          lockedUntil: expiry,
          now: now.add(const Duration(minutes: 30)),
        ),
        isNull,
      );

      expect(
        activePunchLock(
          lockedUserId: 'user-2',
          userId: 'user-2',
          lockedUntil: expiry,
          now: now.add(const Duration(hours: 1, seconds: 1)),
        ),
        isNull,
      );
    });
  });
}
