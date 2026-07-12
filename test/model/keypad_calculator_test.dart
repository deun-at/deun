import 'package:deun/pages/expenses/data/keypad_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a calculator by replaying a sequence of digit / decimal / operator
/// tokens, mirroring how the sheet drives the model from key taps. Tokens:
/// `+ - * /` operators, `.` decimal, anything else a run of digits.
KeypadCalculator _run(String seed, List<String> tokens) {
  var calc = KeypadCalculator.fromText(seed);
  for (final token in tokens) {
    switch (token) {
      case '+':
        calc = calc.applyOperator(KeypadOperator.add);
      case '-':
        calc = calc.applyOperator(KeypadOperator.subtract);
      case '*':
        calc = calc.applyOperator(KeypadOperator.multiply);
      case '/':
        calc = calc.applyOperator(KeypadOperator.divide);
      case '.':
        calc = calc.appendDecimal();
      default:
        for (final ch in token.split('')) {
          calc = calc.appendDigit(ch);
        }
    }
  }
  return calc;
}

void main() {
  group('KeypadCalculator chaining', () {
    test('12.50 + 3.20 + 8 confirms as 23.70', () {
      final calc = _run('0', ['12', '.', '50', '+', '3', '.', '20', '+', '8']);
      expect(calc.hasError, isFalse);
      expect(calc.value, 23.70);
    });

    test('operators resolve left-to-right (no precedence): 2 + 3 * 4 = 20', () {
      final calc = _run('0', ['2', '+', '3', '*', '4']);
      expect(calc.value, 20);
    });

    test('subtraction, multiplication and division chain', () {
      expect(_run('0', ['9', '-', '4']).value, 5);
      expect(_run('0', ['6', '*', '7']).value, 42);
      expect(_run('0', ['20', '/', '5']).value, 4);
    });

    test('pressing an operator twice just swaps the operator', () {
      // 10 + (swap to) - 4 = 6, not 10 + 4.
      final calc = _run('0', ['10', '+', '-', '4']);
      expect(calc.value, 6);
    });
  });

  group('KeypadCalculator decimals & clamping', () {
    test(
      'division rounds the committed result to 2 decimals (10 / 3 = 3.33)',
      () {
        final calc = _run('0', ['10', '/', '3']);
        expect(calc.value, 3.33);
      },
    );

    test('multiplication result is rounded to 2 decimals', () {
      // 2.5 * 1.11 = 2.775 -> 2.78 (rounded).
      final calc = _run('0', ['2', '.', '5', '*', '1', '.', '11']);
      expect(calc.value, 2.78);
    });

    test('each operand still enforces the 2-decimal keypad limit', () {
      // The third decimal of the operand is ignored (5.25, not 5.259).
      final calc = _run('0', ['5', '.', '259']);
      expect(calc.value, 5.25);
    });
  });

  group('KeypadCalculator invalid states', () {
    test('division by zero is an error and cannot be committed', () {
      final calc = _run('0', ['12', '/', '0']);
      expect(calc.hasError, isTrue);
      expect(calc.result, isNull);
    });

    test('a result exceeding 7 integer digits is an error', () {
      // 9999999 * 9 = 89,999,991 -> 8 integer digits, out of range.
      final calc = _run('0', ['9999999', '*', '9']);
      expect(calc.hasError, isTrue);
    });

    test('correcting the divisor clears the error', () {
      final calc = _run('0', ['12', '/', '0', '4']); // divisor becomes 4
      expect(calc.hasError, isFalse);
      expect(calc.value, 3);
    });

    test('confirming with a dangling operator commits the left value', () {
      // "12 +" then equals -> 12 (avoids e.g. "12 / =" dividing by zero).
      expect(_run('0', ['12', '+']).value, 12);
      expect(_run('0', ['12', '/']).hasError, isFalse);
      expect(_run('0', ['12', '/']).value, 12);
    });
  });

  group('KeypadCalculator negatives', () {
    test('a negative final result is committed as-is (5 - 8 = -3)', () {
      final calc = _run('0', ['5', '-', '8']);
      expect(calc.hasError, isFalse);
      expect(calc.value, -3);
    });
  });

  group('KeypadCalculator plain entry (no operators)', () {
    test('behaves like the plain keypad: value is the typed amount', () {
      final calc = _run('0', ['12', '.', '50']);
      expect(calc.hasError, isFalse);
      expect(calc.value, 12.5);
      expect(calc.hasPendingOperation, isFalse);
    });

    test('expression line is empty during plain entry', () {
      final calc = _run('0', ['4', '2']);
      expect(calc.expression, '');
    });
  });

  group('KeypadCalculator expression line', () {
    test('shows the pending value and operator while awaiting an operand', () {
      final calc = _run('0', ['12', '.', '50', '+']);
      expect(calc.expression, '12.50 +');
    });

    test('shows the folded left value, operator and current operand', () {
      final calc = _run('0', ['12', '.', '50', '+', '3']);
      expect(calc.expression, '12.50 + 3');
    });
  });
}
