import 'package:deun/helper/currency_conversion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for multi-currency-home-aggregates. Every assertion
/// restates an acceptance criterion from the plan: mixed-currency contributions
/// are converted into the home currency before summing; converted results are
/// flagged approximate; all-home-currency results are exact; and with rates
/// unavailable the aggregate falls back to home-currency contributions only,
/// counting the excluded ones.
void main() {
  // 1 EUR = 1.10 USD, 1 EUR = 0.80 GBP.
  const rates = ExchangeRates(base: 'EUR', rates: {'USD': 1.10, 'GBP': 0.80});

  group('ExchangeRates.conversionRate', () {
    test('same currency is identity', () {
      expect(rates.conversionRate('EUR', 'EUR'), 1);
      expect(rates.conversionRate('USD', 'USD'), 1);
    });

    test('converts through the base in both directions', () {
      // 1 USD -> EUR = 1 / 1.10.
      expect(rates.conversionRate('USD', 'EUR'), closeTo(1 / 1.10, 1e-9));
      // 1 EUR -> USD = 1.10.
      expect(rates.conversionRate('EUR', 'USD'), closeTo(1.10, 1e-9));
      // 1 USD -> GBP = (0.80 / 1.10).
      expect(rates.conversionRate('USD', 'GBP'), closeTo(0.80 / 1.10, 1e-9));
    });

    test('returns null when a currency has no known rate', () {
      expect(rates.conversionRate('JPY', 'EUR'), isNull);
      expect(rates.conversionRate('EUR', 'JPY'), isNull);
    });

    test('round-trips through the API/cache JSON shape', () {
      final parsed = ExchangeRates.fromApiJson(rates.toCacheJson());
      expect(parsed.base, 'EUR');
      expect(parsed.conversionRate('EUR', 'USD'), closeTo(1.10, 1e-9));
    });
  });

  group('convertToHome', () {
    test('home-currency amount passes through without rates', () {
      expect(convertToHome(10, 'EUR', 'EUR', null), 10);
    });

    test('foreign amount converts with rates', () {
      // $11 in a USD group, home EUR -> 11 / 1.10 = 10.00.
      expect(convertToHome(11, 'USD', 'EUR', rates), closeTo(10, 1e-9));
    });

    test('foreign amount with no rate is excluded (null)', () {
      expect(convertToHome(10, 'USD', 'EUR', null), isNull);
      expect(convertToHome(10, 'JPY', 'EUR', rates), isNull);
    });
  });

  group('convertAndSum mixed-currency aggregation', () {
    test(
      '€10 in a EUR group + \$11 in a USD group is one home total, not 21',
      () {
        // The plan's worked example (with 1 EUR = 1.10 USD so $11 == €10):
        // the home total is €20, never a naive 21.
        final result = convertAndSum(
          const [CurrencyAmount(10, 'EUR'), CurrencyAmount(11, 'USD')],
          'EUR',
          rates,
        );
        expect(result.amount, closeTo(20, 1e-9));
        expect(result.approximate, isTrue);
        expect(result.excludedCount, 0);
      },
    );

    test('all-home-currency contributions are exact (not approximate)', () {
      final result = convertAndSum(
        const [CurrencyAmount(10, 'EUR'), CurrencyAmount(5, 'EUR')],
        'EUR',
        rates,
      );
      expect(result.amount, 15);
      expect(result.approximate, isFalse);
      expect(result.excludedCount, 0);
    });

    test(
      'no rates: falls back to home-currency contributions only, counting the rest',
      () {
        final result = convertAndSum(
          const [
            CurrencyAmount(10, 'EUR'),
            CurrencyAmount(11, 'USD'),
            CurrencyAmount(8, 'GBP'),
          ],
          'EUR',
          null,
        );
        // Only the EUR contribution survives; the two foreign ones are excluded.
        expect(result.amount, 10);
        expect(result.approximate, isFalse);
        expect(result.excludedCount, 2);
      },
    );

    test('home currency other than EUR converts every group into it', () {
      // Home USD: €10 -> $11, $11 -> $11 => $22.
      final result = convertAndSum(
        const [CurrencyAmount(10, 'EUR'), CurrencyAmount(11, 'USD')],
        'USD',
        rates,
      );
      expect(result.amount, closeTo(22, 1e-9));
      expect(result.approximate, isTrue);
    });
  });
}
