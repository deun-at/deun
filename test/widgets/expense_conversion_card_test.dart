// The merged conversion card: the density criteria (no rate field on the
// editor's main screen, in EITHER layout), the provenance the row states, and
// the needs-a-rate state with its save still blocked.

import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_editor_currency_rate_test.dart'
    show
        StubLookup,
        closeConversionSheet,
        installFakePrefs,
        itemizedExpense,
        openConversionSheet,
        pickCurrency,
        prefsValues,
        pumpEditor;

/// A Wednesday expense (2026-07-01) whose quote is effective the previous
/// Tuesday — the weekend/holiday case, where the rate's date is its own fact.
StubLookup _chfLookup() => StubLookup({
  '2026-07-01': RateQuote(rate: 0.9432, effectiveDate: DateTime(2026, 6, 30)),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installFakePrefs);

  /// The three things that left the main screen.
  void expectRateUiAbsent(AppLocalizations l10n) {
    expect(find.byKey(const ValueKey('expense_rate_field')), findsNothing);
    expect(find.byKey(const ValueKey('expense_rate_reset')), findsNothing);
    expect(find.text(l10n.expenseRateRequired), findsNothing);
  }

  /// The two tap targets that replaced them — and that there is no THIRD.
  /// Counting is the point: the criterion is a density one, so naming two
  /// present keys would pass just as well with a fourth control beside them.
  void expectTwoTapTargets(WidgetTester tester) {
    expect(
      find.byKey(const ValueKey('expense_entry_currency')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('expense_conversion_row')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('expense_entry_currency')),
        matching: find.byType(InkWell),
        matchRoot: true,
      ),
      findsOneWidget,
      reason: 'the currency row is one tap target, not a nest of them',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('expense_conversion_row')),
        matching: find.byType(InkWell),
        matchRoot: true,
      ),
      findsOneWidget,
      reason: 'the conversion row is one tap target, not a nest of them',
    );
  }

  testWidgets(
    'the Quick layout carries no rate field and exactly two tap targets',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expectRateUiAbsent(l10n);
      expectTwoTapTargets(tester);
    },
  );

  // One _buildCurrencyAndRate() serves both layouts, and this is what pins it.
  testWidgets(
    'the Itemized layout carries no rate field and exactly two tap targets',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: itemizedExpense(const [1.50, 1.50, 1.50]),
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expectRateUiAbsent(l10n);
      expectTwoTapTargets(tester);
    },
  );

  testWidgets(
    'the rate field, its helper and Clear saved rate are reachable only from the sheet',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // A remembered rate, so "Clear saved rate" has a reason to exist at all.
      prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expectRateUiAbsent(l10n);

      await openConversionSheet(tester);
      expect(find.byKey(const ValueKey('expense_rate_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('expense_rate_reset')), findsOneWidget);
    },
  );

  testWidgets(
    "the conversion row states the converted amount and the rate's effective date",
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        initialAmount: 10,
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('expense_conversion_amount')),
        findsOneWidget,
      );
      // 10 CHF at 0.9432 = 9.43 EUR.
      expect(find.text('EUR 9.43'), findsOneWidget);
      // The chip carries the day the rate was QUOTED (the Tuesday), not the
      // expense's own Wednesday.
      expect(
        find.text(l10n.expenseSourceChip(formatDate('2026-06-30'))),
        findsOneWidget,
      );
    },
  );

  // Three genuinely independent cases, one pump each: re-pumping the editor
  // inside a single test leaves the currency picker's scroll position behind
  // and the second pick misses.
  testWidgets('the fee chip is stated for a non-zero fee on a fetched rate', (
    tester,
  ) async {
    prefsValues[kCardFeePrefKey] = '1.4';
    await pumpEditor(
      tester,
      currencyCode: 'EUR',
      lookupRate: _chfLookup().call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('expense_conversion_fee_chip')),
      findsOneWidget,
    );
  });

  testWidgets('no fee saved: the same fetched rate claims no fee', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      currencyCode: 'EUR',
      lookupRate: _chfLookup().call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('expense_conversion_fee_chip')),
      findsNothing,
    );
  });

  testWidgets(
    'a fee saved but a TYPED rate: no fee was applied, none claimed',
    (tester) async {
      prefsValues[kCardFeePrefKey] = '1.4';
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      await openConversionSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '0.91',
      );
      await tester.pumpAndSettle();
      await closeConversionSheet(tester);

      expect(
        find.byKey(const ValueKey('expense_conversion_fee_chip')),
        findsNothing,
      );
    },
  );

  testWidgets("a typed rate is chipped as the user's own", (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpEditor(
      tester,
      currencyCode: 'EUR',
      lookupRate: _chfLookup().call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();
    await openConversionSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.91',
    );
    await tester.pumpAndSettle();
    await closeConversionSheet(tester);

    expect(find.text(l10n.expenseTypedRateChip), findsOneWidget);
  });

  // Today's expenseRateRequired behaviour, moved but not weakened: no implicit
  // rate, no 1:1 fallback, with or without a fee.
  testWidgets(
    'no rate for the date shows the needs-a-rate state and the save stays blocked',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        initialAmount: 10,
        lookupRate: StubLookup(const {}).call, // nothing for any date
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('expense_conversion_rate_needed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expense_conversion_amount')),
        findsNothing,
      );
      expect(
        find.text(l10n.expenseNoRateChip(formatDate('2026-07-01'))),
        findsOneWidget,
      );

      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pumpAndSettle();

      // The refusal snackbar shows and the editor is still on screen — no
      // write, no pop, and above all no 1:1 fallback.
      expect(find.text(l10n.expenseRateRequired), findsWidgets);
      expect(find.byType(ExpenseDetail), findsOneWidget);
    },
  );

  testWidgets(
    'the source line states the base rate and its date whenever a fee was applied',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      prefsValues[kCardFeePrefKey] = '1.4';
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        lookupRate: _chfLookup().call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      await openConversionSheet(tester);

      // Both numbers on screen: the user can see the percent between them.
      expect(
        find.text(
          l10n.expenseConversionSourceLine(formatDate('2026-06-30'), '0.9432'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
            .controller!
            .text,
        // formatRate keeps 6 SIGNIFICANT digits: 0.9432 x 1.014 = 0.9564048,
        // rendered 0.956405.
        '0.956405',
      );
    },
  );

  // With no fee saved the line is absent — it would duplicate the
  // prefill-date line.
  testWidgets('with no fee saved the source line is absent', (tester) async {
    await pumpEditor(
      tester,
      currencyCode: 'EUR',
      lookupRate: _chfLookup().call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();
    await openConversionSheet(tester);

    expect(
      find.byKey(const ValueKey('expense_conversion_source')),
      findsNothing,
    );
  });
}
