import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/validation/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('someone@example.com'), isNull);
      expect(Validators.email('first.last+tag@sub.example.co.uk'), isNull);
    });

    test('trims surrounding whitespace before judging', () {
      expect(Validators.email('  someone@example.com  '), isNull);
    });

    test('rejects the obvious failures', () {
      expect(Validators.email(''), ValidationError.emailRequired);
      expect(Validators.email(null), ValidationError.emailRequired);
      expect(Validators.email('someone'), ValidationError.emailInvalid);
      expect(Validators.email('someone@'), ValidationError.emailInvalid);
      expect(Validators.email('someone@example'), ValidationError.emailInvalid);
      expect(Validators.email('a b@example.com'), ValidationError.emailInvalid);
    });
  });

  group('Validators.password', () {
    test('requires eight characters', () {
      expect(Validators.password('1234567'), ValidationError.passwordTooShort);
      expect(Validators.password('12345678'), isNull);
    });

    test('distinguishes empty from short', () {
      expect(Validators.password(''), ValidationError.passwordRequired);
    });
  });

  group('Validators.confirmPassword', () {
    test('reports the mismatch only once the password itself is valid', () {
      expect(
        Validators.confirmPassword('short', 'short'),
        ValidationError.passwordTooShort,
      );
      expect(
        Validators.confirmPassword('longenough1', 'longenough2'),
        ValidationError.passwordMismatch,
      );
      expect(Validators.confirmPassword('longenough', 'longenough'), isNull);
    });
  });
}
