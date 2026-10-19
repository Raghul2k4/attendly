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
}
