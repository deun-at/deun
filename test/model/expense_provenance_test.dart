import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _shareJson({
  required String email,
  required double percentage,
  double? fixedAmount,
  double? originalFixedAmount,
}) => {
  'expense_entry_id': 'u1',
  'email': email,
  'display_name': email,
  'percentage': percentage,
  'fixed_amount': fixedAmount,
  'original_fixed_amount': originalFixedAmount,
  'created_at': '2026-08-16T10:00:00',
};

Map<String, dynamic> _entryJson({
  required String id,
  required double amount,
  double? originalAmount,
  int quantity = 1,
  String splitMode = 'equal',
  String? itemGroupId,
  List<Map<String, dynamic>> shares = const [],
}) => {
  'id': id,
  'expense_id': 'exp1',
  'name': 'Ramen',
  'amount': amount,
  'original_amount': originalAmount,
  'quantity': quantity,
  'split_mode': splitMode,
  'item_group_id': itemGroupId,
  'created_at': '2026-08-16T10:00:00',
  'expense_entry_share': shares,
};

Expense _expenseJson({
  String? originalCurrency,
  double? rate,
  String? rateDate,
  List<Map<String, dynamic>>? entries,
  String groupCurrency = 'EUR',
}) => Expense()
  ..loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Ramen',
    'expense_date': '2026-08-16',
    'paid_by': 'a@test.com',
    'created_at': '2026-08-16T10:00:00',
    'is_paid_back_row': false,
    'original_currency_code': originalCurrency,
    'conversion_rate': rate,
    'rate_date': rateDate,
    'group': {
      'id': 'g1',
      'name': 'Tokyo',
      'color_value': 0,
      'simplified_expenses': true,
      'created_at': '',
      'user_id': null,
      'currency_code': groupCurrency,
      'group_member': const [],
      'group_shares_summary': const [],
    },
    'expense_entry':
        entries ?? [_entryJson(id: 'u1', amount: 17.40, originalAmount: 3000)],
  });

void main() {
  group('provenance round-trips through the model', () {
    test('a converted expense loads its currency, rate and rate date', () {
      final e = _expenseJson(
        originalCurrency: 'JPY',
        rate: 0.0058,
        rateDate: '2026-08-16',
      );
      expect(e.originalCurrencyCode, 'JPY');
      expect(e.conversionRate, 0.0058);
      expect(e.rateDate, '2026-08-16');
      expect(e.entryCurrency, Currency.jpy);
    });

    test(
      'the LEDGER amount is the converted one — the original is never summed into it',
      () {
        final e = _expenseJson(
          originalCurrency: 'JPY',
          rate: 0.0058,
          rateDate: '2026-08-16',
        );
        expect(e.amount, 17.40);
        expect(e.originalAmount, 3000);
      },
    );

    test('a numeric column arriving as a string still parses', () {
      // PostgREST returns `numeric` as a JSON string on some server configs,
      // which is why both parsers go through `.toString()`.
      final entry = _entryJson(id: 'u1', amount: 17.40);
      entry['original_amount'] = '3000';
      final e = _expenseJson(
        originalCurrency: 'JPY',
        rate: 0.0058,
        rateDate: '2026-08-16',
        entries: [entry],
      );
      expect(e.expenseEntries['u1']!.originalAmount, 3000);
      expect(e.conversionRate, 0.0058);
    });

    test(
      'a PRE-MIGRATION row (no provenance keys at all) reads as unconverted',
      () {
        final e = Expense()
          ..loadDataFromJson({
            'id': 'exp1',
            'group_id': 'g1',
            'name': 'Ramen',
            'expense_date': '2026-08-16',
            'paid_by': 'a@test.com',
            'created_at': '2026-08-16T10:00:00',
            'is_paid_back_row': false,
            'expense_entry': [
              {
                'id': 'u1',
                'expense_id': 'exp1',
                'name': 'Ramen',
                'amount': 17.40,
                'quantity': 1,
                'split_mode': 'equal',
                'created_at': '2026-08-16T10:00:00',
                'expense_entry_share': const [],
              },
            ],
          });
        expect(e.originalCurrencyCode, isNull);
        expect(e.conversionRate, isNull);
        expect(e.rateDate, isNull);
        expect(e.originalAmount, isNull);
        expect(e.expenseEntries['u1']!.originalAmount, isNull);
        expect(e.amount, 17.40);
      },
    );

    test('originalAmount sums the entries in the ENTRY currency', () {
      final e = _expenseJson(
        originalCurrency: 'CHF',
        rate: 0.9432,
        rateDate: '2026-08-16',
        entries: [
          _entryJson(id: 'u1', amount: 9.44, originalAmount: 10),
          _entryJson(id: 'u2', amount: 9.43, originalAmount: 10),
          _entryJson(id: 'u3', amount: 9.43, originalAmount: 10),
        ],
      );
      expect(e.amount, closeTo(28.30, 1e-9));
      expect(e.originalAmount, 30);
    });
  });

  group('the editor seeds from the ENTERED amount, not the ledger amount', () {
    test(
      'toJson seeds the amount field in the entry currency at its precision',
      () {
        final e = _expenseJson(
          originalCurrency: 'JPY',
          rate: 0.0058,
          rateDate: '2026-08-16',
        );
        expect(e.toJson()['expense_entry[0][amount]'], '3000');
      },
    );

    test(
      'an unconverted expense still seeds from the ledger amount in the group currency',
      () {
        final e = _expenseJson(entries: [_entryJson(id: 'u1', amount: 12.5)]);
        expect(e.toJson()['expense_entry[0][amount]'], '12.50');
      },
    );

    test(
      'editorEntries carries the summed original amount across a claim group',
      () {
        final e = _expenseJson(
          originalCurrency: 'CHF',
          rate: 0.9432,
          rateDate: '2026-08-16',
          entries: [
            _entryJson(
              id: 'u1',
              amount: 9.44,
              originalAmount: 10,
              splitMode: 'claim',
              itemGroupId: 'i1',
            ),
            _entryJson(
              id: 'u2',
              amount: 9.43,
              originalAmount: 10,
              splitMode: 'claim',
              itemGroupId: 'i1',
            ),
            _entryJson(
              id: 'u3',
              amount: 9.43,
              originalAmount: 10,
              splitMode: 'claim',
              itemGroupId: 'i1',
            ),
          ],
        );
        final collapsed = e.editorEntries.single;
        expect(collapsed.quantity, 3);
        expect(collapsed.amount, closeTo(28.30, 1e-9));
        expect(collapsed.originalAmount, 30);
        expect(collapsed.enteredUnitPrice, 10);
      },
    );

    test(
      'a claim group with no provenance collapses to a null original amount',
      () {
        final e = _expenseJson(
          entries: [
            _entryJson(
              id: 'u1',
              amount: 5,
              splitMode: 'claim',
              itemGroupId: 'i1',
            ),
            _entryJson(
              id: 'u2',
              amount: 5,
              splitMode: 'claim',
              itemGroupId: 'i1',
            ),
          ],
        );
        expect(e.editorEntries.single.originalAmount, isNull);
        expect(e.editorEntries.single.enteredUnitPrice, 5);
      },
    );
  });

  group('re-saving an unchanged converted expense is deterministic (frozen)', () {
    test(
      'the same entered amounts at the same frozen rate produce byte-identical ledger values',
      () {
        const conv = ExpenseConversion(
          groupCurrency: Currency.eur,
          entryCurrency: Currency.jpy,
          rate: 0.0058,
          rateDate: '2026-08-16',
        );
        final e = _expenseJson(
          originalCurrency: 'JPY',
          rate: 0.0058,
          rateDate: '2026-08-16',
        );
        final reSaved = conv.toLedger(
          double.parse(e.toJson()['expense_entry[0][amount]'] as String),
        );
        expect(reSaved, e.amount);
        expect(conv.expenseProvenance['conversion_rate'], e.conversionRate);
        expect(conv.expenseProvenance['rate_date'], e.rateDate);
      },
    );
  });

  group('an exact-split share reloads in the ENTRY currency', () {
    // 3 x 1.50 CHF at 0.9432: the ledger holds 4.23 on the entry and 1.41 per
    // share, while the editor's exact fields must hold 1.50.
    Expense converted() => _expenseJson(
      originalCurrency: 'CHF',
      rate: 0.9432,
      rateDate: '2026-08-16',
      entries: [
        _entryJson(
          id: 'u1',
          amount: 4.23,
          originalAmount: 4.50,
          splitMode: 'exact',
          shares: [
            for (final email in ['a@test.com', 'b@test.com', 'c@test.com'])
              _shareJson(
                email: email,
                percentage: 100 / 3,
                fixedAmount: 1.41,
                originalFixedAmount: 1.50,
              ),
          ],
        ),
      ],
    );

    test('the entry knows it was converted', () {
      expect(converted().expenseEntries['u1']!.isConverted, isTrue);
      expect(converted().expenseEntries['u1']!.enteredLineTotal, 4.50);
    });

    test(
      'the entered share is the original, never the ledger fixed_amount',
      () {
        final entry = converted().expenseEntries['u1']!;
        final share = entry.expenseEntryShares.first;
        expect(share.fixedAmount, 1.41);
        expect(share.enteredFixedAmount(isConverted: entry.isConverted), 1.50);
      },
    );

    test(
      're-saving those entered shares reproduces the SAME ledger values',
      () {
        // The defect this guards: seeding from fixed_amount fed 1.41 back as a
        // CHF amount, conv.toLedger halved it again to 1.33, and
        // percentage = 1.41 / 4.50 mixed the two currencies at 31.33% a head
        // (94% total) instead of 33.33%.
        const conv = ExpenseConversion(
          groupCurrency: Currency.eur,
          entryCurrency: Currency.chf,
          rate: 0.9432,
          rateDate: '2026-08-16',
        );
        final entry = converted().expenseEntries['u1']!;
        final entered = [
          for (final s in entry.expenseEntryShares)
            s.enteredFixedAmount(isConverted: entry.isConverted)!,
        ];
        expect(entered, [1.50, 1.50, 1.50]);
        expect(entered.map(conv.toLedger).toList(), [1.41, 1.41, 1.41]);
        final percentages = [
          for (final v in entered) (v / entry.enteredLineTotal) * 100,
        ];
        for (final pct in percentages) {
          expect(pct, closeTo(100 / 3, 1e-9));
        }
        expect(percentages.reduce((a, b) => a + b), closeTo(100, 1e-9));
      },
    );

    test('an UNCONVERTED share still reads its fixed_amount unchanged', () {
      final e = _expenseJson(
        entries: [
          _entryJson(
            id: 'u1',
            amount: 4.50,
            splitMode: 'exact',
            shares: [
              _shareJson(
                email: 'a@test.com',
                percentage: 100 / 3,
                fixedAmount: 1.50,
              ),
            ],
          ),
        ],
      );
      final entry = e.expenseEntries['u1']!;
      expect(entry.isConverted, isFalse);
      expect(entry.expenseEntryShares.first.fixedAmount, 1.50);
      expect(
        entry.expenseEntryShares.first.enteredFixedAmount(isConverted: false),
        1.50,
      );
    });

    test(
      'a converted share with no original falls back to null, not the ledger value',
      () {
        // The caller then derives the amount from the currency-free percentage
        // rather than trusting a group-currency number in an entry-currency
        // field.
        final share = ExpenseEntryShare()
          ..loadDataFromJson(
            _shareJson(
              email: 'a@test.com',
              percentage: 100 / 3,
              fixedAmount: 1.41,
            ),
          );
        expect(share.enteredFixedAmount(isConverted: true), isNull);
      },
    );
  });

  group('a reloaded multi-unit line seeds a unit price that saves back', () {
    test(
      'a 28.30 qty-3 line reopens with enough digits to store 28.30 again',
      () {
        // The one-sided rounding: switch-back wrote the extra digits, the load
        // rounded them away, and the next non-amount edit stored 28.29.
        final e = _expenseJson(
          entries: [
            for (var i = 0; i < 3; i++)
              _entryJson(
                id: 'u$i',
                amount: i == 0 ? 9.44 : 9.43,
                splitMode: 'claim',
                itemGroupId: 'i1',
              ),
          ],
        );
        final collapsed = e.editorEntries.single;
        expect(collapsed.quantity, 3);
        final seed = e.toJson()['expense_entry[0][amount]'] as String;
        expect(seed, isNot('9.43'));
        expect(
          roundCurrency(double.parse(seed) * 3, Currency.eur),
          closeTo(28.30, 1e-9),
        );
      },
    );

    test('an evenly divisible line still seeds the plain unit price', () {
      final e = _expenseJson(entries: [_entryJson(id: 'u1', amount: 12.5)]);
      expect(e.toJson()['expense_entry[0][amount]'], '12.50');
    });
  });

  group('the legacy write path strips provenance before PostgREST', () {
    test('the expense row loses exactly the three provenance keys', () {
      const conv = ExpenseConversion(
        groupCurrency: Currency.eur,
        entryCurrency: Currency.jpy,
        rate: 0.0058,
        rateDate: '2026-08-16',
      );
      final upsert = {
        'name': 'Ramen',
        'group_id': 'g1',
        ...conv.expenseProvenance,
      };
      final stripped = stripProvenance(upsert, kExpenseProvenanceKeys);
      expect(stripped.keys.toSet(), {'name', 'group_id'});
      expect(stripped['name'], 'Ramen');
    });

    test(
      'the share row loses original_fixed_amount but keeps fixed_amount',
      () {
        final stripped = stripProvenance({
          'email': 'a@test.com',
          'percentage': 100 / 3,
          'fixed_amount': 1.41,
          'original_fixed_amount': 1.50,
          'is_locked': false,
        }, kShareProvenanceKeys);
        expect(stripped.keys.toSet(), {
          'email',
          'percentage',
          'fixed_amount',
          'is_locked',
        });
        expect(stripped['fixed_amount'], 1.41);
      },
    );

    test('the entry row loses original_amount but keeps its ledger amount', () {
      final stripped = stripProvenance({
        'name': 'Ramen',
        'amount': 17.40,
        'original_amount': 3000,
        'quantity': 1,
      }, kEntryProvenanceKeys);
      expect(stripped, {'name': 'Ramen', 'amount': 17.40, 'quantity': 1});
    });

    test(
      'an unconverted save is also stripped — the NULL keys would fail PGRST204 too',
      () {
        final identity = ExpenseConversion.identity(Currency.eur);
        final upsert = {'name': 'Ramen', ...identity.expenseProvenance};
        expect(stripProvenance(upsert, kExpenseProvenanceKeys).keys.toSet(), {
          'name',
        });
      },
    );
  });

  group('isForeignCurrencyIn', () {
    test('a JPY expense in a EUR group is foreign', () {
      final e = _expenseJson(
        originalCurrency: 'JPY',
        rate: 0.0058,
        rateDate: '2026-08-16',
      );
      expect(e.isForeignCurrencyIn(Currency.eur), isTrue);
    });

    test('an expense with no original currency is never foreign', () {
      expect(_expenseJson().isForeignCurrencyIn(Currency.eur), isFalse);
    });

    test('an original currency equal to the group currency is not foreign', () {
      final e = _expenseJson(
        originalCurrency: 'EUR',
        rate: 1,
        rateDate: '2026-08-16',
      );
      expect(e.isForeignCurrencyIn(Currency.eur), isFalse);
    });
  });
}
