import 'package:attendance/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('accepts common addresses', () {
      expect(Validators.email('owner@cafe.example.com'), isNull);
      expect(Validators.email('a+tag@sub.domain.co'), isNull);
    });

    test('trims whitespace before validating', () {
      expect(Validators.email('  owner@cafe.example.com\n'), isNull);
    });

    test('rejects empty and malformed values', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@tld'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
      expect(Validators.email('a@b..com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('requires at least 8 characters', () {
      expect(Validators.password('seven77'), isNotNull);
      expect(Validators.password('eight888'), isNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.fullName', () {
    test('requires non-empty trimmed value', () {
      expect(Validators.fullName('  Ada Pullin '), isNull);
      expect(Validators.fullName('   '), isNotNull);
      expect(Validators.fullName(''), isNotNull);
    });

    test('rejects overly long names', () {
      expect(Validators.fullName('x' * 81), isNotNull);
      expect(Validators.fullName('x' * 80), isNull);
    });
  });
}
