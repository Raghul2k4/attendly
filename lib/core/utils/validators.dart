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

  static String? businessName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your business name.';
    if (v.length > 80) return 'Keep the name under 80 characters.';
    return null;
  }

  static String? employeeName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the employee’s name.';
    if (v.length > 80) return 'Keep the name under 80 characters.';
    return null;
  }

  /// Alphabet used by the server for invite tokens. Excludes I, L and O to
  /// keep codes unambiguous when read from paper or chat.
  static final _tokenAlphabet = RegExp(
    r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{20}$',
  );

  /// Normalises user input the same way the server does: uppercase, drop
  /// dashes/whitespace. Exposed so screens can display the cleaned token.
  static String normaliseInviteToken(String value) =>
      value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

  /// Groups a token into readable chunks for display/copy. The server strips
  /// separators, so the grouped form remains valid when pasted later.
  static String formatInviteToken(String token) {
    final normalized = normaliseInviteToken(token);
    final chunks = <String>[];
    for (var i = 0; i < normalized.length; i += 4) {
      chunks.add(normalized.substring(i, (i + 4).clamp(0, normalized.length)));
    }
    return chunks.join('-');
  }

  static String? inviteToken(String? value) {
    final normalized = normaliseInviteToken(value ?? '');
    if (normalized.isEmpty) return 'Enter the invite token your owner shared.';
    if (normalized.length != 20) {
      return 'Invite tokens are 20 characters. Check the code and try again.';
    }
    if (!_tokenAlphabet.hasMatch(normalized)) {
      return 'That token doesn’t look right. Copy it again from your owner.';
    }
    return null;
  }
}
