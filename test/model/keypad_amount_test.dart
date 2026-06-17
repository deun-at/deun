import 'package:deun/pages/expenses/data/keypad_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeypadAmount.fromText', () {
    test('parses an empty / zero string to "0"', () {
      expect(KeypadAmount.fromText('').text, '0');
      expect(KeypadAmount.fromText('0').text, '0');
      expect(KeypadAmount.fromText('00').text, '0');
    });

    test('preserves a valid two-decimal value', () {
      expect(KeypadAmount.fromText('12.50').text, '12.50');
    });

    test('truncates more than two decimals', () {
      expect(KeypadAmount.fromText('12.509').text, '12.50');
    });

    test('truncates more than seven integer digits', () {
      expect(KeypadAmount.fromText('123456789').text, '1234567');
    });
  });

  group('KeypadAmount.appendDigit', () {
    test('replaces the leading zero', () {
      expect(KeypadAmount.fromText('0').appendDigit('5').text, '5');
    });

    test('appends digits to a non-zero integer part', () {
      expect(KeypadAmount.fromText('5').appendDigit('3').text, '53');
    });

    test('appends digits after the decimal point', () {
      expect(KeypadAmount.fromText('5.').appendDigit('2').text, '5.2');
    });

    test('enforces the 2-decimal limit (third decimal is ignored)', () {
      final two = KeypadAmount.fromText('5.25');
      expect(two.appendDigit('9').text, '5.25');
    });

    test('enforces the 7 integer-digit limit (eighth digit is ignored)', () {
      final seven = KeypadAmount.fromText('1234567');
      expect(seven.appendDigit('8').text, '1234567');
    });

    test('still allows a decimal after 7 integer digits', () {
      final seven = KeypadAmount.fromText('1234567');
      expect(seven.appendDecimal().appendDigit('8').text, '1234567.8');
    });

    test('ignores non-digit append input', () {
      expect(KeypadAmount.fromText('5').appendDigit('a').text, '5');
    });
  });

  group('KeypadAmount.appendDecimal', () {
    test('adds a single decimal point', () {
      expect(KeypadAmount.fromText('5').appendDecimal().text, '5.');
    });

    test('is a no-op when a decimal point already exists', () {
      expect(KeypadAmount.fromText('5.2').appendDecimal().text, '5.2');
    });

    test('turns a bare zero into "0."', () {
      expect(KeypadAmount.fromText('0').appendDecimal().text, '0.');
    });
  });

  group('KeypadAmount.backspace', () {
    test('removes the last character', () {
      expect(KeypadAmount.fromText('53').backspace().text, '5');
    });

    test('removes the decimal point', () {
      expect(KeypadAmount.fromText('5.').backspace().text, '5');
    });

    test('collapses to "0" when the last digit is removed', () {
      expect(KeypadAmount.fromText('5').backspace().text, '0');
    });

    test('stays "0" when already zero', () {
      expect(KeypadAmount.fromText('0').backspace().text, '0');
    });
  });

  group('KeypadAmount.value', () {
    test('returns the numeric value', () {
      expect(KeypadAmount.fromText('12.50').value, 12.5);
    });

    test('treats a trailing point as the integer value', () {
      expect(KeypadAmount.fromText('12.').value, 12.0);
    });

    test('zero string is 0', () {
      expect(KeypadAmount.fromText('0').value, 0.0);
    });
  });
}
