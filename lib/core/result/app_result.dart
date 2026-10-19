import '../errors/app_exception.dart';

/// Outcome of a form/async action the UI can branch on without exceptions
/// leaking into widgets. `Failure` carries the mapped, user-facing message.
sealed class AppResult<T> {
  const AppResult();

  factory AppResult.success(T value) = AppSuccess<T>;
  factory AppResult.failure(AppException exception) = AppFailure<T>;

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailure<T>;

  String get failureMessage => switch (this) {
    AppSuccess<T>() => '',
    AppFailure<T>(:final exception) => exception.message,
  };

  AppErrorKind get failureKind => switch (this) {
    AppSuccess<T>() => AppErrorKind.unknown,
    AppFailure<T>(:final exception) => exception.kind,
  };
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);
  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.exception);
  final AppException exception;
}
