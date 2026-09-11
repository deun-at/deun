import 'package:deun/helper/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Currency.fromCode', () {
    test('resolves every code in the curated list', () {
      for (final c in kSupportedCurrencies) {
        expect(Currency.fromCode(c.code), c, reason: '${c.code} must resolve');
      }
    });

    test('JPY has 0 decimal digits, EUR has 2', () {
      expect(Currency.fromCode('JPY').decimalDigits, 0);
      expect(Currency.fromCode('EUR').decimalDigits, 2);
    });

    test('an unknown or null code falls back to EUR instead of throwing', () {
      expect(Currency.fromCode(null), Currency.eur);
      expect(Currency.fromCode(''), Currency.eur);
      expect(Currency.fromCode('XXX'), Currency.eur);
      expect(
        Currency.fromCode('eur'),
        Currency.eur,
      ); // case-sensitive → fallback
    });
  });

  group('the curated list is the ECB / Frankfurter reference set', () {
    test('exactly the 31 ECB reference codes, no more and no fewer', () {
      const ecb = {
        'EUR',
        'USD',
        'JPY',
        'BGN',
        'CZK',
        'DKK',
        'GBP',
        'HUF',
        'PLN',
        'RON',
        'SEK',
        'CHF',
        'ISK',
        'NOK',
        'TRY',
        'AUD',
        'BRL',
        'CAD',
        'CNY',
        'HKD',
        'IDR',
        'ILS',
        'INR',
        'KRW',
        'MXN',
        'MYR',
        'NZD',
        'PHP',
        'SGD',
        'THB',
        'ZAR',
      };
      expect(kSupportedCurrencies.map((c) => c.code).toSet(), ecb);
      expect(kSupportedCurrencies, hasLength(31));
    });

    test('contains at least EUR, USD, GBP, CHF and JPY', () {
      expect(
        kSupportedCurrencies.map((c) => c.code),
        containsAll(<String>['EUR', 'USD', 'GBP', 'CHF', 'JPY']),
      );
    });

    test('no code appears twice', () {
      final codes = kSupportedCurrencies.map((c) => c.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('every entry exposes a non-empty symbol and a sane exponent', () {
      for (final c in kSupportedCurrencies) {
        expect(c.symbol, isNotEmpty, reason: '${c.code} needs a symbol');
        expect(c.decimalDigits, inInclusiveRange(0, 2), reason: c.code);
      }
    });

    test('the list exercises exactly the 0- and 2-decimal cases', () {
      final zero = kSupportedCurrencies
          .where((c) => c.decimalDigits == 0)
          .map((c) => c.code)
          .toSet();
      expect(zero, {'JPY', 'ISK', 'KRW'});
      // No 3-decimal currency is an ECB quote, so none may be listed.
      expect(kSupportedCurrencies.any((c) => c.decimalDigits == 3), isFalse);
    });
  });

  group('minor unit', () {
    test('is 0.01 for a 2-decimal currency and 1 for a 0-decimal one', () {
      expect(Currency.eur.minorUnit, 0.01);
      expect(Currency.jpy.minorUnit, 1.0);
    });

    test('settledEpsilon is half a minor unit', () {
      expect(Currency.eur.settledEpsilon, 0.005);
      expect(Currency.jpy.settledEpsilon, 0.5);
    });
  });

  test('equality and hashing are by code', () {
    expect(Currency.fromCode('USD'), Currency.usd);
    expect(Currency.usd == Currency.eur, isFalse);
    expect({Currency.usd, Currency.fromCode('USD')}, hasLength(1));
  });

  group('name', () {
    test('every supported currency has a non-empty, distinct name', () {
      final names = <String>{};
      for (final c in kSupportedCurrencies) {
        expect(c.name.trim(), isNotEmpty, reason: c.code);
        expect(names.add(c.name), isTrue, reason: '${c.name} is duplicated');
      }
    });

    test('the name is not just the code back again', () {
      for (final c in kSupportedCurrencies) {
        expect(c.name.toUpperCase(), isNot(c.code), reason: c.code);
      }
    });
  });

  group('matches — the picker search', () {
    test('matches the ISO code, case-insensitively', () {
      expect(Currency.chf.matches('chf'), isTrue);
      expect(Currency.chf.matches('CHF'), isTrue);
      expect(Currency.chf.matches('usd'), isFalse);
    });

    test('matches the name on any substring', () {
      // Someone who knows "Swiss Franc" but not "CHF" still finds it.
      expect(Currency.chf.matches('swiss'), isTrue);
      expect(Currency.chf.matches('franc'), isTrue);
      expect(Currency.chf.matches('Franc'), isTrue);
    });

    test('an empty or blank query matches everything', () {
      // Clearing the field restores the list; it must not empty it.
      for (final q in const ['', '   ', '\t']) {
        expect(
          kSupportedCurrencies.where((c) => c.matches(q)).length,
          kSupportedCurrencies.length,
          reason: 'query "$q"',
        );
      }
    });

    test('a query matching nothing yields an empty list, not everything', () {
      expect(kSupportedCurrencies.where((c) => c.matches('zzzz')), isEmpty);
    });

    test('every supported currency is reachable by its own code', () {
      for (final c in kSupportedCurrencies) {
        final hits = kSupportedCurrencies.where((x) => x.matches(c.code));
        expect(hits, contains(c), reason: '${c.code} cannot find itself');
      }
    });
  });
}
