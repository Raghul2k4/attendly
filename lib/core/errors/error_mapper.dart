import 'package:supabase/supabase.dart';

import 'app_exception.dart';

/// Maps transport/SDK failures into one calm, specific [AppException] so
/// screens never surface raw SDK text. Unknown cases stay honest ("couldn't
/// reach the service") without inventing detail.
AppException mapAuthError(Object error, {StackTrace? stackTrace}) {
  if (error is AppException) return error;

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    final status = int.tryParse(error.statusCode ?? '') ?? 0;
    if (message.contains('invalid login credentials')) {
      return AppException(
        'Your email or password is incorrect.',
        kind: AppErrorKind.auth,
        cause: error,
      );
    }
    if (message.contains('email not confirmed') ||
        message.contains('email_not_confirmed')) {
      return AppException(
        'Check your inbox and verify your email before signing in.',
        kind: AppErrorKind.auth,
        cause: error,
      );
    }
    if (message.contains('user already registered') ||
        message.contains('already been registered')) {
      return AppException(
        'An account with this email already exists. Try signing in instead.',
        kind: AppErrorKind.conflict,
        cause: error,
      );
    }
    if (message.contains('rate limit') || status == 429) {
      return AppException(
        'Too many attempts. Wait a moment and try again.',
        kind: AppErrorKind.conflict,
        cause: error,
      );
    }
    if (status == 400 && message.contains('password')) {
      // Server-side password policy message (length/characters) — pass the
      // specific server wording through rather than inventing our own.
      return AppException(
        error.message,
        kind: AppErrorKind.invalidInput,
        cause: error,
      );
    }
    if (status >= 500) {
      return AppException(
        'The service is having trouble right now. Try again shortly.',
        kind: AppErrorKind.server,
        cause: error,
      );
    }
    return AppException(error.message, kind: AppErrorKind.auth, cause: error);
  }

  if (error is PostgrestException) {
    if (error.code == '42501') {
      return AppException(
        "You don't have permission to do that.",
        kind: AppErrorKind.permission,
        cause: error,
      );
    }
    return AppException(
      'We couldn’t save that. Check the details and try again.',
      kind: AppErrorKind.server,
      cause: error,
    );
  }

  final isNetwork =
      error.toString().contains('ClientException') ||
      error.toString().contains('SocketException') ||
      error.toString().contains('Connection');
  if (isNetwork) {
    return AppException(
      'You seem offline. Check your connection and try again.',
      kind: AppErrorKind.network,
      cause: error,
    );
  }

  return AppException(
    'Something unexpected happened. Please try again.',
    kind: AppErrorKind.unknown,
    cause: error,
  );
}
