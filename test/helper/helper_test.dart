import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';

void main() {
  group('toHumanDateString', () {
    test('formats ISO date to dd.MM.yyyy', () {
      expect(toHumanDateString('2024-03-15'), '15.03.2024');
    });

    test('formats datetime string', () {
      expect(toHumanDateString('2024-03-15T14:30:00'), '15.03.2024');
    });

    test('null returns empty string', () {
      expect(toHumanDateString(null), '');
    });

    test('first day of year', () {
      expect(toHumanDateString('2024-01-01'), '01.01.2024');
    });

    test('last day of year', () {
      expect(toHumanDateString('2024-12-31'), '31.12.2024');
    });
  });

  group('roundCurrency', () {
    test('rounds drift from addition to exact cents', () {
      expect(roundCurrency(0.1 + 0.2, Currency.eur), 0.3);
    });

    test('rounds repeating thirds to cents', () {
      expect(roundCurrency(100 / 3, Currency.eur), 33.33);
      expect(roundCurrency(200 / 3, Currency.eur), 66.67);
    });

    test('keeps exact values unchanged', () {
      expect(roundCurrency(12.34, Currency.eur), 12.34);
    });

    test('rounds negative values', () {
      expect(roundCurrency(-200 / 3, Currency.eur), -66.67);
    });
  });

  group('isSettled', () {
    test('a zero balance is settled', () {
      expect(isSettled(0, Currency.eur), isTrue);
    });

    test('below half a cent is settled, in both signs', () {
      expect(isSettled(0.004, Currency.eur), isTrue);
      expect(isSettled(-0.004, Currency.eur), isTrue);
    });

    test('half a cent is outstanding, in both signs', () {
      expect(isSettled(0.005, Currency.eur), isFalse);
      expect(isSettled(-0.005, Currency.eur), isFalse);
    });

    test('0.007 is outstanding — one answer, not two', () {
      // The payment screen said outstanding (0.005) and the group list said
      // settled (0.01) for this exact value.
      expect(isSettled(0.007, Currency.eur), isFalse);
    });

    test('settled means exactly "renders as 0.00"', () {
      expect(roundCurrency(0.004, Currency.eur), 0.0);
      expect(roundCurrency(0.005, Currency.eur), 0.01);
      expect(kSettledEpsilon, 0.005);
    });
  });

  group('roundCurrency is currency-aware', () {
    test('2-decimal behaviour is preserved exactly', () {
      expect(roundCurrency(0.1 + 0.2, Currency.eur), 0.3);
      expect(roundCurrency(100 / 3, Currency.eur), 33.33);
      expect(roundCurrency(200 / 3, Currency.eur), 66.67);
      expect(roundCurrency(-200 / 3, Currency.eur), -66.67);
      expect(roundCurrency(12.34, Currency.eur), 12.34);
    });

    test('rounding 12.345 in EUR yields 12.35', () {
      expect(roundCurrency(12.345, Currency.eur), 12.35);
    });

    test('a 0-decimal currency rounds to whole units', () {
      expect(roundCurrency(2500.4, Currency.jpy), 2500);
      expect(roundCurrency(2500.6, Currency.jpy), 2501);
      expect(roundCurrency(-2500.6, Currency.jpy), -2501);
    });

    test('every 2-decimal currency rounds identically to EUR', () {
      for (final c in kSupportedCurrencies.where((c) => c.decimalDigits == 2)) {
        expect(roundCurrency(100 / 3, c), 33.33, reason: c.code);
      }
    });
  });

  group('isSettled is currency-aware', () {
    test('EUR: true below half a cent, false at and above it', () {
      expect(isSettled(0.004, Currency.eur), isTrue);
      expect(isSettled(-0.004, Currency.eur), isTrue);
      expect(isSettled(0.006, Currency.eur), isFalse);
      expect(isSettled(0.005, Currency.eur), isFalse);
      expect(isSettled(0, Currency.eur), isTrue);
    });

    test('JPY: true below half a yen, false at and above it', () {
      expect(isSettled(0.4, Currency.jpy), isTrue);
      expect(isSettled(-0.4, Currency.jpy), isTrue);
      expect(isSettled(0.6, Currency.jpy), isFalse);
      expect(isSettled(0.5, Currency.jpy), isFalse);
    });

    test('0.007 is still outstanding in EUR — one answer, not two', () {
      expect(isSettled(0.007, Currency.eur), isFalse);
    });

    test('settled still means exactly "renders as zero"', () {
      expect(roundCurrency(0.004, Currency.eur), 0.0);
      expect(roundCurrency(0.005, Currency.eur), 0.01);
      expect(roundCurrency(0.4, Currency.jpy), 0.0);
      expect(roundCurrency(0.6, Currency.jpy), 1.0);
    });

    test('the server-side filter constant equals EUR\'s epsilon', () {
      // GroupRepository.activeBalanceFilter cannot take a Currency; this pins
      // it to the client predicate so the tabs cannot drift.
      expect(kSettledEpsilon, Currency.eur.settledEpsilon);
    });
  });

  group('amountToFieldText', () {
    test('EUR keeps two decimals, dot-separated', () {
      expect(amountToFieldText(12.5, Currency.eur), '12.50');
      expect(double.parse(amountToFieldText(12.5, Currency.eur)), 12.5);
    });

    test('JPY writes a whole number', () {
      expect(amountToFieldText(3000, Currency.jpy), '3000');
      expect(amountToFieldText(2500.6, Currency.jpy), '2501');
    });
  });

  group('escapeHtml', () {
    test('escapes html-relevant characters', () {
      expect(
        escapeHtml('<script>alert("x&y")</script>'),
        '&lt;script&gt;alert(&quot;x&amp;y&quot;)&lt;/script&gt;',
      );
    });

    test('null becomes empty string', () {
      expect(escapeHtml(null), '');
    });

    test('plain text passes through', () {
      expect(escapeHtml('Hello World'), 'Hello World');
    });
  });

  group('formatDate', () {
    test('null returns empty string', () {
      expect(formatDate(null), '');
    });

    test('today returns "Today"', () {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(formatDate(todayStr), 'Today');
    });

    test('yesterday returns "Yesterday"', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final str =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(formatDate(str), 'Yesterday');
    });

    test('different year shows full date with year', () {
      expect(formatDate('2020-06-15'), contains('2020'));
    });
  });
}
