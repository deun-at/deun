import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sumByCurrency / currencyBreakdownOf', () {
    test('never sums unlike currencies: one entry per currency', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.eur, 25.50),
        CurrencyAmount(Currency.jpy, 3000),
        CurrencyAmount(Currency.eur, 4.50),
      ]);
      expect(b.primary, const CurrencyAmount(Currency.jpy, 3000));
      expect(b.others, const [CurrencyAmount(Currency.eur, 30.0)]);
      expect(b.hiddenCount, 1);
      expect(b.isSingleCurrency, isFalse);
    });

    test('primary is the largest ABSOLUTE amount, sign included', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.eur, 10),
        CurrencyAmount(Currency.usd, -40),
      ]);
      expect(b.primary, const CurrencyAmount(Currency.usd, -40));
    });

    test('ties break by ISO code ascending, not by map iteration order', () {
      final forward = currencyBreakdownOf(const [
        CurrencyAmount(Currency.usd, 10),
        CurrencyAmount(Currency.gbp, -10),
      ]);
      final reversed = currencyBreakdownOf(const [
        CurrencyAmount(Currency.gbp, -10),
        CurrencyAmount(Currency.usd, 10),
      ]);
      expect(forward.primary.currency, Currency.gbp);
      expect(reversed.primary.currency, Currency.gbp);
      expect(forward, reversed);
    });

    test('a single currency reports isSingleCurrency and hides nothing', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.eur, 12),
        CurrencyAmount(Currency.eur, -2),
      ]);
      expect(b.isSingleCurrency, isTrue);
      expect(b.hiddenCount, 0);
      expect(b.primary, const CurrencyAmount(Currency.eur, 10.0));
    });

    test('exactly two currencies hide exactly one — never a count of zero', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.eur, 20),
        CurrencyAmount(Currency.chf, 5),
      ]);
      expect(b.hiddenCount, 1);
      expect(b.others.single.currency, Currency.chf);
    });

    test('each currency rounds and settles at its OWN precision', () {
      // 0.4 JPY is settled (half a yen); 0.6 is not. 0.004 EUR is settled;
      // 0.006 is not.
      expect(
        currencyBreakdownOf(const [CurrencyAmount(Currency.jpy, 0.4)]).primary,
        const CurrencyAmount(Currency.jpy, 0),
      );
      expect(
        currencyBreakdownOf(const [CurrencyAmount(Currency.jpy, 0.6)]).primary,
        const CurrencyAmount(Currency.jpy, 1),
      );
      expect(
        currencyBreakdownOf(const [
          CurrencyAmount(Currency.eur, 0.004),
        ]).isSingleCurrency,
        isTrue,
      );
      expect(
        currencyBreakdownOf(const [
          CurrencyAmount(Currency.eur, 0.006),
        ]).primary.amount,
        0.01,
      );
    });

    test('an all-settled mix still renders a zero, and hides nothing', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.jpy, 0.4),
        CurrencyAmount(Currency.eur, 0.004),
      ]);
      expect(b.primary, const CurrencyAmount(Currency.eur, 0));
      expect(b.isSingleCurrency, isTrue, reason: 'no zero-count disclosure');
    });

    test('no contributions yields the EUR-zero empty breakdown', () {
      expect(currencyBreakdownOf(const []), CurrencyBreakdown.empty);
      expect(CurrencyBreakdown.empty.isSingleCurrency, isTrue);
    });

    test('all lists primary first, then the remainder in the same order', () {
      final b = currencyBreakdownOf(const [
        CurrencyAmount(Currency.eur, 5),
        CurrencyAmount(Currency.jpy, 3000),
        CurrencyAmount(Currency.usd, 20),
      ]);
      expect(b.all.map((a) => a.currency.code).toList(), ['JPY', 'USD', 'EUR']);
    });

    test('formatCurrencyAmounts names each amount in its own currency', () {
      expect(
        formatCurrencyAmounts(const [
          CurrencyAmount(Currency.eur, 10),
          CurrencyAmount(Currency.jpy, 3000),
        ], const Locale('en')),
        '€10.00 + ¥3,000',
      );
    });

    test(
      'a single amount formats exactly as formatMoney does (no join noise)',
      () {
        expect(
          formatCurrencyAmounts(const [
            CurrencyAmount(Currency.eur, 25.5),
          ], const Locale('en')),
          formatMoney(25.5, Currency.eur, const Locale('en')),
        );
      },
    );
  });

  group('dropSettled: the spending fold keeps what the balance fold drops', () {
    // A currency the user only ever PAID in nets a ~0 share. As a balance that
    // is nothing owed and must not take a disclosure row; as spending it is a
    // real currency whose "you paid" total and trend series are reachable only
    // through the selector, so dropping it makes them unreachable.
    const paidOnly = [
      CurrencyAmount(Currency.eur, 300),
      CurrencyAmount(Currency.jpy, 0),
    ];

    test('the default (balance) fold drops the settled currency', () {
      final b = currencyBreakdownOf(paidOnly);
      expect(b.primary, const CurrencyAmount(Currency.eur, 300));
      expect(b.isSingleCurrency, isTrue);
    });

    test('dropSettled: false keeps it, so the selector can still reach it', () {
      final b = currencyBreakdownOf(paidOnly, dropSettled: false);
      expect(b.primary, const CurrencyAmount(Currency.eur, 300));
      expect(b.others, const [CurrencyAmount(Currency.jpy, 0)]);
      expect(b.hiddenCount, 1);
    });

    test('sumByCurrency still rounds at each currency\'s own precision', () {
      expect(
        sumByCurrency(const [
          CurrencyAmount(Currency.jpy, 0.4),
        ], dropSettled: false),
        const [CurrencyAmount(Currency.jpy, 0)],
      );
      expect(
        sumByCurrency(const [
          CurrencyAmount(Currency.eur, 0.004),
        ], dropSettled: false),
        const [CurrencyAmount(Currency.eur, 0)],
      );
    });

    test(
      'an empty input is still the empty breakdown, not a zero disclosure',
      () {
        expect(
          currencyBreakdownOf(const [], dropSettled: false),
          CurrencyBreakdown.empty,
        );
      },
    );
  });
}
