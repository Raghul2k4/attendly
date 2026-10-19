/// Severity/kind of an [AppException]; drives iconography and recovery UI.
enum AppErrorKind {
  network,
  auth,
  invalidInput,
  permission,
  conflict,
  server,
  unknown,
}

/// The single user-facing error type across the app. Carries calm, specific
/// microcopy (never raw stack traces) plus a kind for icon/recovery choices.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.kind = AppErrorKind.unknown,
    this.cause,
  });

  final String message;
  final AppErrorKind kind;
  final Object? cause;

  @override
  String toString() => 'AppException(${kind.name}): $message';
}
