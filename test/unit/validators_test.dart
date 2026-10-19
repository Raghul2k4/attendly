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

  group('Validators.businessName', () {
    test('requires a name and caps length', () {
      expect(Validators.businessName('Corner Cafe'), isNull);
      expect(Validators.businessName('   '), isNotNull);
      expect(Validators.businessName('x' * 81), isNotNull);
    });
  });

  group('Validators.workplaceName', () {
    test('requires a name and caps length', () {
      expect(Validators.workplaceName('Main shop'), isNull);
      expect(Validators.workplaceName('  Main shop  '), isNull);
      expect(Validators.workplaceName(''), isNotNull);
      expect(Validators.workplaceName('   '), isNotNull);
      expect(Validators.workplaceName('x' * 80), isNull);
      expect(Validators.workplaceName('x' * 81), isNotNull);
    });
  });

  group('Validators.inviteToken', () {
    const raw = 'ABCDEFGHJKMNPQRSTUVW';

    test('accepts grouped, mixed-case tokens by normalising them', () {
      expect(Validators.inviteToken('abcd-efgh-jkmn-pqrs-tuvw'), isNull);
      expect(Validators.inviteToken(' ABCD EFGH JKMN PQRS TUVW '), isNull);
      expect(Validators.normaliseInviteToken('abcd efgh'), 'ABCDEFGH');
    });

    test('rejects wrong length and ambiguous characters', () {
      expect(Validators.inviteToken(''), isNotNull);
      expect(Validators.inviteToken(raw.substring(0, 19)), isNotNull);
      expect(
        Validators.inviteToken(raw.replaceFirst('K', 'I')),
        isNotNull,
        reason: 'I/L/O are excluded from the token alphabet',
      );
    });

    test('formats 20-character tokens into fours for sharing', () {
      expect(Validators.formatInviteToken(raw), 'ABCD-EFGH-JKMN-PQRS-TUVW');
    });
  });
}
