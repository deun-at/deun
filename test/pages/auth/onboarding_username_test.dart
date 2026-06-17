import 'package:deun/pages/auth/onboarding_username.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeUsername', () {
    test('lowercases uppercase characters', () {
      expect(sanitizeUsername('JohnDoe'), 'johndoe');
    });

    test('strips spaces', () {
      expect(sanitizeUsername('john doe'), 'johndoe');
    });

    test('strips symbols outside [a-zA-Z0-9_]', () {
      expect(sanitizeUsername('jöhn.d@e-1!'), 'jhnde1');
    });

    test('keeps digits and underscores', () {
      expect(sanitizeUsername('a_b_9'), 'a_b_9');
    });

    test('trims surrounding whitespace', () {
      expect(sanitizeUsername('  jane  '), 'jane');
    });

    test('empty input yields empty string', () {
      expect(sanitizeUsername(''), '');
    });
  });

  group('isValidUsername', () {
    test('2 chars is invalid', () {
      expect(isValidUsername('ab'), false);
    });

    test('3 chars is valid', () {
      expect(isValidUsername('abc'), true);
    });

    test('20 chars is valid', () {
      expect(isValidUsername('a' * 20), true);
    });

    test('21 chars is invalid', () {
      expect(isValidUsername('a' * 21), false);
    });

    test('symbol makes it invalid', () {
      expect(isValidUsername('ab!c'), false);
    });

    test('underscores and digits are valid', () {
      expect(isValidUsername('john_doe_99'), true);
    });

    test('empty is invalid', () {
      expect(isValidUsername(''), false);
    });
  });

  group('previewHandle', () {
    test('empty username falls back to a placeholder username', () {
      expect(
        previewHandle(username: '', codePlaceholder: '0000'),
        '@username#0000',
      );
    });

    test('builds @username#code for typical input', () {
      expect(
        previewHandle(username: 'jane', codePlaceholder: '0000'),
        '@jane#0000',
      );
    });
  });
}
