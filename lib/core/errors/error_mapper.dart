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

/// Maps errors from the backend functions and PostgREST reads into calm
/// user-facing copy. Backend functions raise `ATT:<code>` (see docs/PLAN.md
/// for the full contract); unknown cases fall back to the same honest
/// transport guidance as auth failures.
AppException mapBackendError(Object error, {StackTrace? stackTrace}) {
  if (error is AppException) return error;

  if (error is PostgrestException) {
    final code = RegExp(r'ATT:([a-z_]+)').firstMatch(error.message)?.group(1);

    final (String, AppErrorKind)? copy = switch (code) {
      'not_authenticated' => (
        'Your session expired. Sign in again.',
        AppErrorKind.auth,
      ),
      'invalid_org_name' => (
        'Enter a valid business name.',
        AppErrorKind.invalidInput,
      ),
      'unknown_timezone' => (
        'That timezone isn’t supported. Pick another one.',
        AppErrorKind.invalidInput,
      ),
      'org_create_failed' => (
        'We couldn’t create the organisation. Try again.',
        AppErrorKind.server,
      ),
      'unknown_plan' => (
        'This plan isn’t available right now. Try again later.',
        AppErrorKind.server,
      ),
      'org_not_found' => (
        'This organisation couldn’t be found. Refresh and try again.',
        AppErrorKind.conflict,
      ),
      'invalid_employee_name' => (
        'Enter a valid employee name.',
        AppErrorKind.invalidInput,
      ),
      'not_org_owner' => (
        'Only the business owner can do that.',
        AppErrorKind.permission,
      ),
      'plan_limit_reached' => (
        'Your plan is full. Deactivate a team member before adding someone '
            'new — or upgrade your plan.',
        AppErrorKind.conflict,
      ),
      'invalid_invite_token' => (
        'That invite token doesn’t look right. Check it and try again.',
        AppErrorKind.invalidInput,
      ),
      'workplace_not_found' => (
        'That workplace couldn’t be found. Refresh and try again.',
        AppErrorKind.conflict,
      ),
      'workplace_inactive' => (
        'This workplace is inactive. Reactivate it before generating a QR '
            'code.',
        AppErrorKind.conflict,
      ),
      'invite_token_not_found' => (
        'This invite token isn’t valid or was already used. Ask your owner '
            'for a new one.',
        AppErrorKind.conflict,
      ),
      'already_member_of_org' => (
        'You’re already part of this organisation.',
        AppErrorKind.conflict,
      ),
      'already_active_employee' => (
        'You’re already an active employee somewhere. Ask that business '
            'owner to deactivate you before joining another team.',
        AppErrorKind.conflict,
      ),
      'member_not_found' => (
        'That team member couldn’t be found. Refresh and try again.',
        AppErrorKind.conflict,
      ),
      'owner_status_immutable' => (
        'The owner account can’t be deactivated.',
        AppErrorKind.permission,
      ),
      'status_unchanged' => (
        'That’s already their status.',
        AppErrorKind.conflict,
      ),
      'member_not_claimed' => (
        'This person hasn’t accepted their invite yet.',
        AppErrorKind.conflict,
      ),
      'user_active_elsewhere' => (
        'This person is already active in another organisation.',
        AppErrorKind.conflict,
      ),
      'invalid_status' => (
        'That status change isn’t supported.',
        AppErrorKind.invalidInput,
      ),
      'plan_change_not_allowed' ||
      'owner_change_not_allowed' ||
      'protected_field_change_not_allowed' ||
      'org_reassignment_not_allowed' => (
        'That change isn’t allowed here.',
        AppErrorKind.permission,
      ),
      _ => null,
    };

    if (copy != null) {
      return AppException(copy.$1, kind: copy.$2, cause: error);
    }
    if (error.code == '42501') {
      return AppException(
        "You don't have permission to do that.",
        kind: AppErrorKind.permission,
        cause: error,
      );
    }
    if (error.code == '23514') {
      return AppException(
        'Check the workplace details and try again.',
        kind: AppErrorKind.invalidInput,
        cause: error,
      );
    }
    if (error.code == '23503') {
      return AppException(
        'That record no longer exists. Refresh and try again.',
        kind: AppErrorKind.conflict,
        cause: error,
      );
    }
    if (error.code == 'PGRST116') {
      return AppException(
        'This record isn’t available anymore. Refresh and try again.',
        kind: AppErrorKind.conflict,
        cause: error,
      );
    }
    return AppException(
      'We couldn’t save that. Check the details and try again.',
      kind: AppErrorKind.server,
      cause: error,
    );
  }

  if (error is AuthException) {
    return mapAuthError(error, stackTrace: stackTrace);
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
