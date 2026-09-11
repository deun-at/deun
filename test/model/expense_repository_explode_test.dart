import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';

void main() {
  group('ExpenseRepository.explodeItemizedEntry', () {
    test('qty 3 item becomes 3 unit entries each amount = unit price', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 5.0,
        quantity: 3,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
      );

      expect(units.length, 3);
      for (final unit in units) {
        final entry = unit['entry'] as Map<String, dynamic>;
        expect(entry['amount'], 5.0);
        expect(entry['quantity'], 1);
        expect(entry['split_mode'], 'claim');
        expect(entry['item_group_seq'], 1);
        expect(entry['name'], 'Beer');
        expect(
          (unit['shares'] as List).isEmpty,
          isTrue,
        ); // new units start unclaimed
      }
    });

    test('sort_id increments per unit so order is stable', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 5.0,
        quantity: 2,
        itemGroupSeq: 1,
        sortIdStart: 20,
        currency: Currency.eur,
      );
      expect((units[0]['entry'] as Map)['sort_id'], 20);
      expect((units[1]['entry'] as Map)['sort_id'], 21);
    });

    test('qty 1 produces exactly one unit', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Wine',
        unitPrice: 8.5,
        quantity: 1,
        itemGroupSeq: 2,
        sortIdStart: 10,
        currency: Currency.eur,
      );
      expect(units.length, 1);
      expect((units[0]['entry'] as Map)['amount'], 8.5);
    });

    test('qty 0 is treated as 1 (guard)', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Odd',
        unitPrice: 2.0,
        quantity: 0,
        itemGroupSeq: 3,
        sortIdStart: 10,
        currency: Currency.eur,
      );
      expect(units.length, 1);
    });
  });

  group('ExpenseRepository.explodeItemizedEntry with unitClaims (F146)', () {
    test('existing claims are preserved per unit on re-explode', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 2.5,
        quantity: 3,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
        unitClaims: [
          ['a@test.com'],
          [],
          ['a@test.com', 'b@test.com'],
        ],
      );

      expect(units.length, 3);
      final shares0 = units[0]['shares'] as List;
      expect(shares0.length, 1);
      expect((shares0[0] as Map)['email'], 'a@test.com');
      expect((shares0[0] as Map)['percentage'], 100);

      expect((units[1]['shares'] as List), isEmpty);

      final shares2 = units[2]['shares'] as List;
      expect(shares2.length, 2);
      expect((shares2[0] as Map)['percentage'], 50);
      expect((shares2[1] as Map)['percentage'], 50);
    });

    test('units beyond the old quantity start unclaimed', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 2.5,
        quantity: 3,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
        unitClaims: [
          ['a@test.com'],
        ],
      );
      expect((units[0]['shares'] as List).length, 1);
      expect((units[1]['shares'] as List), isEmpty);
      expect((units[2]['shares'] as List), isEmpty);
    });

    test('shrinking the quantity drops trailing claims', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 2.5,
        quantity: 1,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
        unitClaims: [
          ['a@test.com'],
          ['b@test.com'],
        ],
      );
      expect(units.length, 1);
      expect(((units[0]['shares'] as List)[0] as Map)['email'], 'a@test.com');
    });
  });

  group('ExpenseRepository.explodeItemizedEntry converts the LINE once', () {
    const chfIntoEur = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.chf,
      rate: 0.9432,
      rateDate: '2026-08-16',
    );

    test(
      '3 x 10.00 CHF at 0.9432 stores units summing to 28.30, not 28.29',
      () {
        final units = ExpenseRepository.explodeItemizedEntry(
          name: 'Beer',
          unitPrice: 10.0,
          quantity: 3,
          itemGroupSeq: 1,
          sortIdStart: 10,
          currency: Currency.eur,
          conversion: chfIntoEur,
        );
        final amounts = units
            .map((u) => (u['entry'] as Map)['amount'] as double)
            .toList();
        expect(amounts, [9.44, 9.43, 9.43]);
        expect(amounts.reduce((a, b) => a + b), closeTo(28.30, 1e-9));
      },
    );

    test('each unit records its ORIGINAL amount in the entry currency', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 10.0,
        quantity: 3,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
        conversion: chfIntoEur,
      );
      for (final unit in units) {
        expect((unit['entry'] as Map)['original_amount'], 10.0);
      }
    });

    test('with no conversion the unit rows carry a null original amount', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 5.0,
        quantity: 2,
        itemGroupSeq: 1,
        sortIdStart: 10,
        currency: Currency.eur,
      );
      for (final unit in units) {
        expect((unit['entry'] as Map)['original_amount'], isNull);
        expect((unit['entry'] as Map)['amount'], 5.0);
      }
    });

    test('a foreign currency with no rate refuses to explode', () {
      const noRate = ExpenseConversion(
        groupCurrency: Currency.eur,
        entryCurrency: Currency.chf,
        rate: null,
        rateDate: null,
      );
      expect(
        () => ExpenseRepository.explodeItemizedEntry(
          name: 'Beer',
          unitPrice: 10.0,
          quantity: 3,
          itemGroupSeq: 1,
          sortIdStart: 10,
          currency: Currency.eur,
          conversion: noRate,
        ),
        throwsA(isA<MissingConversionRateException>()),
      );
    });

    test(
      'a switched-back line re-explodes into the SAME units it had while converted',
      () {
        // A qty-3 CHF line at 0.9432: 10.00 x3 -> 28.30 EUR, distributed.
        final converted = ExpenseRepository.explodeItemizedEntry(
          name: 'Beer',
          unitPrice: 10.0,
          quantity: 3,
          itemGroupSeq: 1,
          sortIdStart: 10,
          currency: Currency.eur,
          conversion: chfIntoEur,
        );
        // Switching the expense back to EUR rewrites the amount field. Feeding
        // that text back through an IDENTITY save must reproduce the ledger to
        // the cent — this is the whole point of the switch-back rule.
        final text = switchBackAmountTexts(
          enteredTexts: ['10.00'],
          rate: 0.9432,
          groupCurrency: Currency.eur,
          quantities: [3],
        ).single;
        final switchedBack = ExpenseRepository.explodeItemizedEntry(
          name: 'Beer',
          unitPrice: double.parse(text),
          quantity: 3,
          itemGroupSeq: 1,
          sortIdStart: 10,
          currency: Currency.eur,
        );

        List<double> amountsOf(List<Map<String, dynamic>> units) =>
            units.map((u) => (u['entry'] as Map)['amount'] as double).toList();
        expect(amountsOf(converted), [9.44, 9.43, 9.43]);
        expect(amountsOf(switchedBack), amountsOf(converted));
        expect(
          amountsOf(switchedBack).reduce((a, b) => a + b),
          closeTo(28.30, 1e-9),
        );
        // The provenance is gone, the ledger value is not.
        for (final unit in switchedBack) {
          expect((unit['entry'] as Map)['original_amount'], isNull);
        }
      },
    );
  });
}
