import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('mapAuthError', () {
    test('invalid credentials becomes specific auth message', () {
      final mapped = mapAuthError(
        AuthException('Invalid login credentials', statusCode: '400'),
      );
      expect(mapped.kind, AppErrorKind.auth);
      expect(mapped.message, 'Your email or password is incorrect.');
    });

    test('unconfirmed email explains the inbox step', () {
      final mapped = mapAuthError(
        AuthException('Email not confirmed', statusCode: '400'),
      );
      expect(mapped.kind, AppErrorKind.auth);
      expect(mapped.message, contains('verify your email'));
    });

    test('duplicate registration suggests signing in', () {
      final mapped = mapAuthError(
        AuthException('User already registered', statusCode: '422'),
      );
      expect(mapped.kind, AppErrorKind.conflict);
      expect(mapped.message, contains('already exists'));
    });

    test('rate limiting is honest and calm', () {
      final mapped = mapAuthError(
        AuthException('Rate limit exceeded', statusCode: '429'),
      );
      expect(mapped.kind, AppErrorKind.conflict);
      expect(mapped.message, contains('Too many attempts'));
    });

    test('server errors admit the service is struggling', () {
      final mapped = mapAuthError(AuthException('boom', statusCode: '500'));
      expect(mapped.kind, AppErrorKind.server);
    });

    test('password policy errors pass the server message through', () {
      final mapped = mapAuthError(
        AuthException(
          'Password should be at least 8 characters',
          statusCode: '400',
        ),
      );
      expect(mapped.kind, AppErrorKind.invalidInput);
      expect(mapped.message, contains('Password should be at least 8'));
    });

    test('row-level rejections become permission errors', () {
      final mapped = mapAuthError(
        PostgrestException(message: 'row-level security', code: '42501'),
      );
      expect(mapped.kind, AppErrorKind.permission);
    });

    test('network failures get offline guidance', () {
      final mapped = mapAuthError(Exception('ClientException: failed connect'));
      expect(mapped.kind, AppErrorKind.network);
    });

    test('app exceptions pass through unchanged', () {
      const original = AppException('Keep this.', kind: AppErrorKind.auth);
      final mapped = mapAuthError(original);
      expect(identical(original, mapped), isTrue);
    });
  });

  group('mapBackendError', () {
    PostgrestException att(String code) =>
        PostgrestException(message: 'ATT:$code', code: 'P0001');

    test('seat limit gets specific upgrade guidance', () {
      final mapped = mapBackendError(att('plan_limit_reached'));
      expect(mapped.kind, AppErrorKind.conflict);
      expect(mapped.message, contains('plan is full'));
    });

    test('used invite tokens explain that a new one is needed', () {
      final mapped = mapBackendError(att('invite_token_not_found'));
      expect(mapped.kind, AppErrorKind.conflict);
      expect(mapped.message, contains('already used'));
    });

    test('owner-only actions map to permission errors', () {
      final mapped = mapBackendError(att('not_org_owner'));
      expect(mapped.kind, AppErrorKind.permission);
      expect(mapped.message, contains('business owner'));
    });

    test('duplicate active employee is explained calmly', () {
      final mapped = mapBackendError(att('already_active_employee'));
      expect(mapped.kind, AppErrorKind.conflict);
      expect(mapped.message, contains('active employee'));
    });

    test('unknown ATT codes stay honest about saving failing', () {
      final mapped = mapBackendError(att('some_future_code'));
      expect(mapped.kind, AppErrorKind.server);
      expect(mapped.message, contains('couldn’t save'));
    });

    test('row-level rejections map to permission', () {
      final mapped = mapBackendError(
        PostgrestException(message: 'row-level security', code: '42501'),
      );
      expect(mapped.kind, AppErrorKind.permission);
    });

    test('app exceptions pass through unchanged', () {
      const original = AppException('Keep this.', kind: AppErrorKind.conflict);
      expect(identical(original, mapBackendError(original)), isTrue);
    });
  });
}
