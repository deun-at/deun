// The card fee, where it actually decides money: the rate that lands in the
// editor and the conversion the save writes.
//
// The invariant under test throughout is `_RateOrigin`: the fee rides on a
// FETCHED rate and on nothing else, which is what makes double-application
// impossible without storing it.

import 'dart:convert';

import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The editor harness, shared with the suite that owns the rate field.
import 'expense_editor_currency_rate_test.dart'
    show
        StubLookup,
        closeConversionSheet,
        convertedExpense,
        installFakePrefs,
        openConversionSheet,
        pickCurrency,
        prefsValues,
        pumpEditorWithSaveSeam,
        saveEditor;

String _rateText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
    .controller!
    .text;

/// Seeds the fee through the fake preference store — what "with a 1.4% fee
/// saved" means, and it exercises the real hydration path rather than a stub.
void _saveFee(String value) => prefsValues[kCardFeePrefKey] = value;

/// 5 170 HUF in a EUR group, at the ECB base from the bug walk. The harness
/// expense is dated 2026-07-01.
StubLookup _hufLookup() => StubLookup({
  '2026-07-01': RateQuote(rate: 0.0027405, effectiveDate: DateTime(2026, 7, 1)),
});

/// The conversion row's amount. `matchRoot` because the key sits ON the Text,
/// not on an ancestor — a plain descendant finder would exclude it.
Finder _conversionAmount(String text) => find.descendant(
  of: find.byKey(const ValueKey('expense_conversion_amount')),
  matching: find.text(text),
  matchRoot: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installFakePrefs);

  // AC: with a 1.4% fee saved, a FETCHED rate converts at base x 1.014 —
  // 5 170 HUF at 0.0027405 settles at 14.37, not 14.17.
  testWidgets(
    'a fetched rate carries the saved fee: 5 170 HUF settles at EUR 14.37',
    (tester) async {
      _saveFee('1.4');
      final lookup = _hufLookup();
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        initialAmount: 5170,
        lookupRate: lookup.call,
      );
      await pickCurrency(tester, 'HUF');
      await tester.pumpAndSettle();

      expect(_conversionAmount('EUR 14.37'), findsOneWidget);

      await saveEditor(tester);
      expect(saved.single.conversion!.toLedger(5170), 14.37);
    },
  );

  // The same expense, no fee: the ECB number, unchanged.
  testWidgets('the same expense with no fee saved settles at EUR 14.17', (
    tester,
  ) async {
    final lookup = _hufLookup();
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      initialAmount: 5170,
      lookupRate: lookup.call,
    );
    await pickCurrency(tester, 'HUF');
    await tester.pumpAndSettle();

    expect(_conversionAmount('EUR 14.17'), findsOneWidget);

    await saveEditor(tester);
    expect(saved.single.conversion!.toLedger(5170), 14.17);
  });

  // AC: a rate the user TYPED is never modified. 0.0027699 is the statement
  // rate from the bug walk — it already includes their bank's markup.
  testWidgets('a rate the user TYPED is never modified by the fee', (
    tester,
  ) async {
    _saveFee('1.4');
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      initialAmount: 5170,
      lookupRate: _hufLookup().call,
    );
    await pickCurrency(tester, 'HUF');
    await tester.pumpAndSettle();
    await openConversionSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.0027699',
    );
    await tester.pumpAndSettle();
    await closeConversionSheet(tester);

    // The chip is the visible half of the invariant: no fee was applied, so
    // none is claimed.
    expect(
      find.byKey(const ValueKey('expense_conversion_fee_chip')),
      findsNothing,
    );

    await saveEditor(tester);
    expect(saved.single.conversion!.rate, 0.0027699);
    expect(saved.single.conversion!.toLedger(5170), 14.32);
  });

  // AC: a STICKY prefill is not modified either — it is a rate the user typed
  // on an earlier expense, so it is theirs.
  testWidgets('a sticky rate prefill is never modified by the fee', (
    tester,
  ) async {
    _saveFee('1.4');
    prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|HUF': 0.0027699});
    final lookup = _hufLookup();
    await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      initialAmount: 5170,
      lookupRate: lookup.call,
    );
    await pickCurrency(tester, 'HUF');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // A remembered rate outranks the prefill, so nothing is even fetched.
    expect(lookup.calls, isEmpty);
    expect(find.text(l10n.expenseTypedRateChip), findsOneWidget);

    await openConversionSheet(tester);
    expect(_rateText(tester), '0.0027699');
  });

  // AC: reopening a saved converted expense and re-saving it stores the same
  // rate and the same converted amount. The fee is never applied twice.
  testWidgets(
    'reopening a saved converted expense and re-saving applies the fee no second time',
    (tester) async {
      _saveFee('1.4');
      final lookup = _hufLookup();
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedExpense(), // JPY 3000 @ 0.0058 -> 17.40 EUR
        lookupRate: lookup.call,
      );
      await tester.pumpAndSettle();
      await saveEditor(tester);

      expect(saved.single.conversion!.rate, 0.0058);
      expect(saved.single.conversion!.rateDate, '2026-08-16');
      expect(saved.single.conversion!.toLedger(3000), 17.40);
      expect(lookup.calls, isEmpty);
    },
  );

  // AC: changing the fee recomputes from the base rate already fetched and
  // issues NO new request.
  testWidgets(
    'changing the fee recomputes from the fetched base and issues no new request',
    (tester) async {
      final lookup = _hufLookup();
      await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        initialAmount: 5170,
        lookupRate: lookup.call,
      );
      await pickCurrency(tester, 'HUF');
      await tester.pumpAndSettle();
      await openConversionSheet(tester);
      expect(_rateText(tester), '0.0027405');
      expect(lookup.calls, hasLength(1));

      // Set 1.4% through the fee row, exactly as a user reaches it.
      await tester.tap(
        find.byKey(const ValueKey('expense_conversion_fee_row')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('card_fee_field')),
        '1.4',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card_fee_save')));
      await tester.pumpAndSettle();

      expect(_rateText(tester), '0.00277887');
      expect(
        lookup.calls,
        hasLength(1),
        reason: 'the rate for a pair and a date is immutable — never refetch',
      );
      expect(
        find.byKey(const ValueKey('expense_conversion_fee_chip')),
        findsOneWidget,
      );

      // Clearing it the same way returns the field to the untouched base.
      await tester.tap(
        find.byKey(const ValueKey('expense_conversion_fee_row')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('card_fee_field')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card_fee_save')));
      await tester.pumpAndSettle();

      expect(_rateText(tester), '0.0027405');
      expect(lookup.calls, hasLength(1));
      await closeConversionSheet(tester);
      expect(
        find.byKey(const ValueKey('expense_conversion_fee_chip')),
        findsNothing,
      );
    },
  );

  // AC: a fee of 0 is indistinguishable from no fee saved.
  testWidgets('a fee of 0 is indistinguishable from no fee saved', (
    tester,
  ) async {
    _saveFee('0');
    final lookup = _hufLookup();
    await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      initialAmount: 5170,
      lookupRate: lookup.call,
    );
    await pickCurrency(tester, 'HUF');
    await tester.pumpAndSettle();

    expect(_conversionAmount('EUR 14.17'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('expense_conversion_fee_chip')),
      findsNothing,
    );

    await openConversionSheet(tester);
    expect(_rateText(tester), '0.0027405');
  });
}
