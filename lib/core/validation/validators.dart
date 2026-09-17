/// Pure validation predicates.
///
/// They return a [ValidationError] rather than a message so the same rule can be
/// rendered in en/fr/ar; the presentation layer resolves it against [L10n].
enum ValidationError {
  emailRequired,
  emailInvalid,
  passwordRequired,
  passwordTooShort,
  passwordMismatch,
  amountRequired,
  amountNotPositive,
  nameRequired,
  categoryRequired,
  rateNotPositive,
}

abstract final class Validators {
  /// Deliberately permissive: one `@`, a dot-bearing domain, no spaces. Stricter
  /// regexes reject valid addresses, and the real check is the confirmation mail.
  static final RegExp _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]"
    r'(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  static const int minPasswordLength = 8;

  static ValidationError? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return ValidationError.emailRequired;
    if (!_email.hasMatch(trimmed)) return ValidationError.emailInvalid;
    return null;
  }

  static ValidationError? password(String? value) {
    if (value == null || value.isEmpty) return ValidationError.passwordRequired;
    if (value.length < minPasswordLength) {
      return ValidationError.passwordTooShort;
    }
    return null;
  }

  static ValidationError? confirmPassword(String? value, String? original) {
    final base = password(value);
    if (base != null) return base;
    if (value != original) return ValidationError.passwordMismatch;
    return null;
  }

  static ValidationError? requiredName(String? value) =>
      (value?.trim().isEmpty ?? true) ? ValidationError.nameRequired : null;

  static ValidationError? positiveRate(double? value) =>
      (value == null || value <= 0) ? ValidationError.rateNotPositive : null;
}
