/// Pure validation helpers — no Flutter imports so they unit-test instantly.
/// Each returns a user-facing message or `null` when the value is valid.
class Validators {
  static final _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Enter your email address.';
    }
    if (!_emailPattern.hasMatch(v)) {
      return 'That email address doesn’t look right.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name.';
    if (v.length > 80) return 'Keep the name under 80 characters.';
    return null;
  }
}
