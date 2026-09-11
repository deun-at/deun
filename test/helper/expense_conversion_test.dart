import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/itemized_totals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ledgerFixedAmounts', () {
    const chfToEur = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.chf,
      rate: 0.9432,
      rateDate: '2026-09-11',
    );

    test('a converted exact split allocates the whole entry total', () {
      // 3 x 1.50 CHF at 0.9432. The line converts once to 4.24; converting each
      // share on its own gives 1.41 three times, which is 4.23 — a cent adrift
      // from the very entry those shares belong to.
      final out = ledgerFixedAmounts(
        enteredByEmail: const {'a@x': 1.50, 'b@x': 1.50, 'c@x': 1.50},
        entryTotal: 4.24,
        conv: chfToEur,
        payer: 'c@x',
      );

      expect(out.values.fold<double>(0, (s, v) => s + v), 4.24);
      expect(out['c@x'], 1.42, reason: 'the payer carries the spare cent');
      expect(out['a@x'], 1.41);
      expect(out['b@x'], 1.41);
    });

    test('an uneven converted split keeps each share proportional', () {
      final out = ledgerFixedAmounts(
        enteredByEmail: const {'a@x': 1.00, 'b@x': 3.50},
        entryTotal: roundCurrency(4.50 * 0.9432, Currency.eur),
        conv: chfToEur,
        payer: 'a@x',
      );

      expect(out.values.fold<double>(0, (s, v) => s + v), 4.24);
      // 1.00 -> 0.9432 and 3.50 -> 3.3012, which round to 0.94 and 3.30 and
      // already account for the whole 4.24 — an uneven split need not produce a
      // spare unit at all, and when it doesn't, nobody is nudged.
      expect(out['a@x'], 0.94);
      expect(out['b@x'], 3.30);
    });

    test('an unconverted exact split keeps the amounts the user typed', () {
      final out = ledgerFixedAmounts(
        enteredByEmail: const {'a@x': 1.50, 'b@x': 1.25, 'c@x': 1.75},
        entryTotal: 4.50,
        conv: ExpenseConversion.identity(Currency.eur),
        payer: 'a@x',
      );

      expect(out['a@x'], 1.50);
      expect(out['b@x'], 1.25);
      expect(out['c@x'], 1.75);
    });

    test('an unconverted split that does not add up is left alone', () {
      // The user's own numbers are theirs. Only a conversion may reshape them.
      final out = ledgerFixedAmounts(
        enteredByEmail: const {'a@x': 1.00, 'b@x': 1.00},
        entryTotal: 5.00,
        conv: ExpenseConversion.identity(Currency.eur),
        payer: 'a@x',
      );

      expect(out['a@x'], 1.00);
      expect(out['b@x'], 1.00);
    });
  });

  group('ymd', () {
    test('pads single-digit month and day', () {
      expect(ymd(DateTime(2026, 8, 6)), '2026-08-06');
      expect(ymd(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('convertToGroupCurrency respects both currencies decimal digits', () {
    test('3000 JPY at 0.0058 into a EUR group stores 17.40', () {
      expect(convertToGroupCurrency(3000, 0.0058, Currency.eur), 17.40);
    });

    test('20 EUR at 172 into a JPY group stores 3440 with no fraction', () {
      final converted = convertToGroupCurrency(20, 172, Currency.jpy);
      expect(converted, 3440);
      expect(converted, converted.roundToDouble());
    });

    test('a 2-decimal to 2-decimal conversion rounds to cents', () {
      // 30 CHF at 0.9432 = 28.296 -> 28.30, the figure the preview shows.
      expect(convertToGroupCurrency(30, 0.9432, Currency.eur), 28.30);
    });

    test('an identity rate of 1 is a no-op at the target precision', () {
      expect(convertToGroupCurrency(12.345, 1, Currency.eur), 12.35);
      expect(convertToGroupCurrency(2500.6, 1, Currency.jpy), 2501);
    });
  });

  group('distributeCurrency — parts sum to the whole', () {
    test(
      'an indivisible EUR total spreads its remainder over leading parts',
      () {
        final parts = distributeCurrency(28.30, 3, Currency.eur);
        expect(parts, [9.44, 9.43, 9.43]);
        expect(parts.reduce((a, b) => a + b), closeTo(28.30, 1e-9));
      },
    );

    test('a divisible total splits evenly', () {
      expect(distributeCurrency(15.0, 3, Currency.eur), [5.0, 5.0, 5.0]);
    });

    test('a 0-decimal currency distributes whole units', () {
      final parts = distributeCurrency(3440, 3, Currency.jpy);
      expect(parts, [1147, 1147, 1146]);
      expect(parts.reduce((a, b) => a + b), 3440);
    });

    test('a negative total (discount line) still sums back exactly', () {
      final parts = distributeCurrency(-0.07, 3, Currency.eur);
      expect(parts.reduce((a, b) => a + b), closeTo(-0.07, 1e-9));
    });

    test('one part is the whole', () {
      expect(distributeCurrency(28.296, 1, Currency.eur), [28.30]);
    });
  });

  group('parseConversionRate — there is no implicit rate', () {
    test('an emptied field ("0" from the formatter) is null, not zero', () {
      expect(parseConversionRate('0'), isNull);
    });

    test('null, empty and non-numeric text are null', () {
      expect(parseConversionRate(null), isNull);
      expect(parseConversionRate(''), isNull);
      expect(parseConversionRate('abc'), isNull);
    });

    test('a negative rate is refused', () {
      expect(parseConversionRate('-0.9'), isNull);
    });

    test('a comma-typed rate parses', () {
      expect(parseConversionRate('0,9432'), 0.9432);
    });

    test('a valid rate parses', () {
      expect(parseConversionRate('172'), 172.0);
      expect(parseConversionRate(' 0.0058 '), 0.0058);
    });
  });

  group('formatRate', () {
    test(
      'trims trailing zeros and round-trips through parseConversionRate',
      () {
        expect(formatRate(0.0058), '0.0058');
        expect(formatRate(172), '172');
        expect(formatRate(0.9432), '0.9432');
        expect(parseConversionRate(formatRate(0.0058)), 0.0058);
      },
    );
  });

  group('ExpenseConversion', () {
    final eurGroup = ExpenseConversion.identity(Currency.eur);
    const jpyIntoEur = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.jpy,
      rate: 0.0058,
      rateDate: '2026-08-16',
    );
    const noRate = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.chf,
      rate: null,
      rateDate: null,
    );

    test('identity only rounds, it does not convert', () {
      expect(eurGroup.isIdentity, isTrue);
      expect(eurGroup.toLedger(12.345), 12.35);
    });

    test('a foreign currency converts at the frozen rate', () {
      expect(jpyIntoEur.isIdentity, isFalse);
      expect(jpyIntoEur.toLedger(3000), 17.40);
    });

    test(
      'a foreign currency with no rate REFUSES rather than falling back to 1:1',
      () {
        expect(
          () => noRate.toLedger(30),
          throwsA(isA<MissingConversionRateException>()),
        );
      },
    );

    test('a foreign currency with a zero rate also refuses', () {
      const zero = ExpenseConversion(
        groupCurrency: Currency.eur,
        entryCurrency: Currency.chf,
        rate: 0,
        rateDate: '2026-08-16',
      );
      expect(
        () => zero.toLedger(30),
        throwsA(isA<MissingConversionRateException>()),
      );
    });

    test('provenance carries the currency, rate and date', () {
      expect(jpyIntoEur.expenseProvenance, {
        'original_currency_code': 'JPY',
        'conversion_rate': 0.0058,
        'rate_date': '2026-08-16',
      });
    });

    test(
      'identity provenance is all three keys explicitly null, so a switch back CLEARS the row',
      () {
        expect(eurGroup.expenseProvenance, {
          'original_currency_code': null,
          'conversion_rate': null,
          'rate_date': null,
        });
        expect(eurGroup.expenseProvenance.keys.toSet(), kExpenseProvenanceKeys);
      },
    );
  });

  group('unit amounts for a claimable multi-quantity line', () {
    const chfIntoEur = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.chf,
      rate: 0.9432,
      rateDate: '2026-08-16',
    );

    test(
      'the LINE converts once; units sum to the previewed total, not 28.29',
      () {
        final units = unitLedgerAmounts(
          enteredLineTotal: 30,
          quantity: 3,
          conversion: chfIntoEur,
        );
        expect(units, [9.44, 9.43, 9.43]);
        expect(units.reduce((a, b) => a + b), closeTo(28.30, 1e-9));
        // Converting per unit would have produced 3 x 9.43 = 28.29.
        expect(units.reduce((a, b) => a + b), isNot(closeTo(28.29, 1e-9)));
        expect(
          units.reduce((a, b) => a + b),
          closeTo(chfIntoEur.toLedger(30), 1e-9),
        );
      },
    );

    test(
      'original amounts are distributed in the ENTRY currency and sum to the entered line',
      () {
        final originals = unitOriginalAmounts(
          enteredLineTotal: 30,
          quantity: 3,
          conversion: chfIntoEur,
        );
        expect(originals, [10.0, 10.0, 10.0]);
        expect(originals!.reduce((a, b) => a + b), closeTo(30, 1e-9));
      },
    );

    test('an identity conversion records no original amounts', () {
      expect(
        unitOriginalAmounts(
          enteredLineTotal: 30,
          quantity: 3,
          conversion: ExpenseConversion.identity(Currency.eur),
        ),
        isNull,
      );
    });

    test('quantity 0 is treated as one unit', () {
      expect(
        unitLedgerAmounts(
          enteredLineTotal: 30,
          quantity: 0,
          conversion: chfIntoEur,
        ),
        [28.30],
      );
    });
  });

  group('ledgerTotalOfLines — the preview is the figure the save stores', () {
    const chfIntoEur = ExpenseConversion(
      groupCurrency: Currency.eur,
      entryCurrency: Currency.chf,
      rate: 0.9432,
      rateDate: '2026-08-16',
    );

    test('three 1.50 CHF lines at 0.9432 total 4.23, not 4.24', () {
      final lines = [
        for (var i = 0; i < 3; i++)
          const ItemLine(unitPrice: 1.50, quantity: 1),
      ];
      // Each line converts on its own (1.50 x 0.9432 = 1.4148 -> 1.41), the way
      // saveAll accumulates. Converting the SUMMED 4.50 once gives 4.2444 ->
      // 4.24, a cent the ledger never holds.
      expect(ledgerTotalOfLines(lines, chfIntoEur), 4.23);
      expect(
        convertToGroupCurrency(itemizedTotal(lines), 0.9432, Currency.eur),
        4.24,
      );
    });

    test('the total is the sum of the per-line ledger totals', () {
      final lines = [
        const ItemLine(unitPrice: 1.50, quantity: 1),
        const ItemLine(unitPrice: 10.00, quantity: 3),
        const ItemLine(unitPrice: -0.80, quantity: 1),
      ];
      final perLine = lines
          .map((line) => ledgerLineTotal(line, chfIntoEur))
          .toList();
      expect(perLine, [1.41, 28.30, -0.75]);
      expect(ledgerTotalOfLines(lines, chfIntoEur), 28.96);
      expect(perLine.reduce((a, b) => a + b), closeTo(28.96, 1e-9));
    });

    test('a multi-quantity line converts its LINE total, not its unit', () {
      // 10.00 x3 = 30.00 CHF -> 28.296 -> 28.30. Per unit it would be
      // 9.4320 -> 9.43 x3 = 28.29.
      expect(
        ledgerLineTotal(
          const ItemLine(unitPrice: 10.0, quantity: 3),
          chfIntoEur,
        ),
        28.30,
      );
      expect(
        unitLedgerAmounts(
          enteredLineTotal: 30,
          quantity: 3,
          conversion: chfIntoEur,
        ).reduce((a, b) => a + b),
        closeTo(
          ledgerLineTotal(
            const ItemLine(unitPrice: 10.0, quantity: 3),
            chfIntoEur,
          ),
          1e-9,
        ),
      );
    });

    test('an identity conversion only rounds — the total is unchanged', () {
      final lines = [
        const ItemLine(unitPrice: 1.50, quantity: 3),
        const ItemLine(unitPrice: 2.25, quantity: 1),
      ];
      expect(
        ledgerTotalOfLines(lines, ExpenseConversion.identity(Currency.eur)),
        6.75,
      );
    });

    test('no lines is a zero total, not a throw', () {
      expect(ledgerTotalOfLines(const [], chfIntoEur), 0);
    });

    test(
      'a foreign currency with no rate REFUSES rather than previewing 1:1',
      () {
        const noRate = ExpenseConversion(
          groupCurrency: Currency.eur,
          entryCurrency: Currency.chf,
          rate: null,
          rateDate: null,
        );
        expect(
          () => ledgerTotalOfLines([
            const ItemLine(unitPrice: 1.50, quantity: 1),
          ], noRate),
          throwsA(isA<MissingConversionRateException>()),
        );
      },
    );
  });

  group(
    'rateDateForPickedCurrency — a changed currency or rate re-stamps the date',
    () {
      final today = DateTime(2026, 9, 2);

      test('re-picking the loaded currency AND rate keeps its FROZEN date', () {
        expect(
          rateDateForPickedCurrency(
            picked: Currency.jpy,
            loadedOriginalCurrencyCode: 'JPY',
            loadedRateDate: '2026-08-16',
            loadedRate: 0.0058,
            pickedRate: 0.0058,
            today: today,
          ),
          '2026-08-16',
        );
      });

      test('switching JPY -> CHF stamps today, not the old JPY rate date', () {
        expect(
          rateDateForPickedCurrency(
            picked: Currency.chf,
            loadedOriginalCurrencyCode: 'JPY',
            loadedRateDate: '2026-08-16',
            loadedRate: 0.0058,
            pickedRate: null,
            today: today,
          ),
          '2026-09-02',
        );
      });

      test('a currency picked on an unconverted expense stamps today', () {
        expect(
          rateDateForPickedCurrency(
            picked: Currency.chf,
            loadedOriginalCurrencyCode: null,
            loadedRateDate: null,
            loadedRate: null,
            pickedRate: 0.9432,
            today: today,
          ),
          '2026-09-02',
        );
      });

      test('a loaded currency with no stored date still stamps today', () {
        expect(
          rateDateForPickedCurrency(
            picked: Currency.jpy,
            loadedOriginalCurrencyCode: 'JPY',
            loadedRateDate: null,
            loadedRate: 0.0058,
            pickedRate: 0.0058,
            today: today,
          ),
          '2026-09-02',
        );
      });

      test(
        'the loaded currency re-picked with a DIFFERENT rate stamps today',
        () {
          // The CHF -> EUR -> CHF round trip: the field was cleared and
          // refilled from the sticky rate, which was never quoted on the
          // loaded date.
          expect(
            rateDateForPickedCurrency(
              picked: Currency.chf,
              loadedOriginalCurrencyCode: 'CHF',
              loadedRateDate: '2026-08-16',
              loadedRate: 0.9432,
              pickedRate: 0.9500,
              today: today,
            ),
            '2026-09-02',
          );
        },
      );

      test('the loaded currency re-picked with NO rate stamps today', () {
        expect(
          rateDateForPickedCurrency(
            picked: Currency.chf,
            loadedOriginalCurrencyCode: 'CHF',
            loadedRateDate: '2026-08-16',
            loadedRate: 0.9432,
            pickedRate: null,
            today: today,
          ),
          '2026-09-02',
        );
      });
    },
  );

  group('unitPriceFieldTextForTotal — the inverse of the save', () {
    test('an evenly divisible line seeds the plain unit price', () {
      expect(unitPriceFieldTextForTotal(30, 3, Currency.chf), '10.00');
      expect(unitPriceFieldTextForTotal(12.5, 1, Currency.eur), '12.50');
      expect(unitPriceFieldTextForTotal(3000, 1, Currency.jpy), '3000');
    });

    test(
      'a line whose remainder was distributed keeps the digits that save it back',
      () {
        // 28.30 over 3 units is 9.44 / 9.43 / 9.43. Seeding "9.43" would store
        // 28.29 on the next save of an otherwise untouched expense.
        final text = unitPriceFieldTextForTotal(28.30, 3, Currency.eur);
        expect(text, isNot('9.43'));
        expect(roundCurrency(double.parse(text) * 3, Currency.eur), 28.30);
      },
    );

    test('it agrees with switchBackAmountTexts for the same line', () {
      // Both sides of the save/reload boundary hand the field the same text,
      // so a switch-back followed by a reload is a fixed point.
      final switched = switchBackAmountTexts(
        enteredTexts: const ['10.00'],
        rate: 0.9432,
        groupCurrency: Currency.eur,
        quantities: const [3],
      ).single;
      expect(unitPriceFieldTextForTotal(28.30, 3, Currency.eur), switched);
    });

    test('a zero or negative quantity is treated as one unit', () {
      expect(unitPriceFieldTextForTotal(28.30, 0, Currency.eur), '28.30');
    });
  });

  group(
    'unitPriceFieldText — a unit price that saves back to its line total',
    () {
      test('an evenly divisible line keeps the plain per-unit text', () {
        expect(unitPriceFieldText(const [5.0, 5.0, 5.0], Currency.eur), '5.00');
      });

      test('a single unit is just the amount', () {
        expect(unitPriceFieldText(const [28.30], Currency.eur), '28.30');
      });

      test(
        'a distributed line keeps the digits that reproduce the whole, not 9.43',
        () {
          final text = unitPriceFieldText(const [
            9.44,
            9.43,
            9.43,
          ], Currency.eur);
          expect(text, isNot('9.43'));
          // What the save will do with it: unit price x quantity, rounded.
          expect(roundCurrency(double.parse(text) * 3, Currency.eur), 28.30);
        },
      );

      test('a distributed 0-decimal line also reproduces its total', () {
        final text = unitPriceFieldText(const [1147, 1147, 1146], Currency.jpy);
        expect(roundCurrency(double.parse(text) * 3, Currency.jpy), 3440);
      });

      test('a distributed negative (discount) line reproduces its total', () {
        final text = unitPriceFieldText(const [
          -0.03,
          -0.02,
          -0.02,
        ], Currency.eur);
        expect(roundCurrency(double.parse(text) * 3, Currency.eur), -0.07);
      });
    },
  );

  group('switchBackAmountTexts — the frozen rate preserves the ledger value', () {
    test('a converted 3000 JPY at 0.0058 becomes 17.40, not 3000', () {
      expect(
        switchBackAmountTexts(
          enteredTexts: ['3000'],
          rate: 0.0058,
          groupCurrency: Currency.eur,
        ),
        ['17.40'],
      );
    });

    test('every itemized line is re-converted independently', () {
      expect(
        switchBackAmountTexts(
          enteredTexts: ['10.00', '20.00'],
          rate: 0.9432,
          groupCurrency: Currency.eur,
        ),
        ['9.43', '18.86'],
      );
    });

    test('the result is at the GROUP currency precision', () {
      expect(
        switchBackAmountTexts(
          enteredTexts: ['20'],
          rate: 172,
          groupCurrency: Currency.jpy,
        ),
        ['3440'],
      );
    });

    test(
      'with no rate the typed numbers pass through untouched, never cleared',
      () {
        expect(
          switchBackAmountTexts(
            enteredTexts: ['3000', '12.50'],
            rate: null,
            groupCurrency: Currency.eur,
          ),
          ['3000', '12.50'],
        );
      },
    );

    test(
      'a non-positive rate also passes through rather than zeroing the amounts',
      () {
        expect(
          switchBackAmountTexts(
            enteredTexts: ['3000'],
            rate: 0,
            groupCurrency: Currency.eur,
          ),
          ['3000'],
        );
      },
    );

    test('an unparseable field is left exactly as it was', () {
      expect(
        switchBackAmountTexts(
          enteredTexts: ['', 'abc', '10'],
          rate: 0.5,
          groupCurrency: Currency.eur,
        ),
        ['', 'abc', '5.00'],
      );
    });

    test(
      'a qty-3 line keeps its 28.30 ledger total, never 9.43 x3 = 28.29',
      () {
        final texts = switchBackAmountTexts(
          enteredTexts: ['10.00'],
          rate: 0.9432,
          groupCurrency: Currency.eur,
          quantities: [3],
        );
        expect(texts.single, isNot('9.43'));
        // The line total the save will recompute from the written-back field.
        expect(
          roundCurrency(double.parse(texts.single) * 3, Currency.eur),
          28.30,
        );
      },
    );

    test('a qty-3 line that divides evenly keeps the clean per-unit text', () {
      // 10.00 x3 = 30.00 CHF at 0.5 is 15.00, and 15.00 / 3 is exactly 5.00.
      expect(
        switchBackAmountTexts(
          enteredTexts: ['10.00'],
          rate: 0.5,
          groupCurrency: Currency.eur,
          quantities: [3],
        ),
        ['5.00'],
      );
    });

    test('quantities are matched per line, and a missing one is one unit', () {
      final texts = switchBackAmountTexts(
        enteredTexts: ['10.00', '20.00'],
        rate: 0.9432,
        groupCurrency: Currency.eur,
        // Only the first line's quantity is supplied.
        quantities: [3],
      );
      expect(roundCurrency(double.parse(texts[0]) * 3, Currency.eur), 28.30);
      expect(texts[1], '18.86');
    });

    test('a qty-0 line is treated as one unit', () {
      expect(
        switchBackAmountTexts(
          enteredTexts: ['3000'],
          rate: 0.0058,
          groupCurrency: Currency.eur,
          quantities: [0],
        ),
        ['17.40'],
      );
    });
  });
}
