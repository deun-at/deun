import 'dart:convert';
import 'dart:io';

import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every key this feature deletes: reachable from no Dart file under lib/ or
/// test/, and money- or mode-related in the expense editor's vocabulary.
/// Acceptance: "Any money- or mode-related l10n key that turns out to have no
/// Dart callers is deleted rather than left in the ARB files."
const _deletedKeys = <String>[
  'createExpense',
  'editExpense',
  'addExpenseTitle',
  'expenseAmount',
  'expenseAmountValidationEmpty',
  'expenseEntryTitle',
  'expenseYourNetLabel',
  'expenseYouLent',
  'expenseYouOwe',
  'expenseEntryAmount',
  'expenseEntrySharesLable',
  'totalExpensesAmount',
  'splitModeAmount',
  'totalLabel',
];

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  // AC3 — the German edit labels are German, not the English string copied over.
  test('the editor edit labels differ between en and de', () {
    expect(en.save, 'Save');
    expect(de.save, 'Speichern');
    expect(de.save, isNot(en.save));

    expect(en.expenseSaveAndShareForClaimingEdit, 'Save & share for claiming');
    expect(
      de.expenseSaveAndShareForClaimingEdit,
      'Speichern & zum Beanspruchen teilen',
    );
    expect(
      de.expenseSaveAndShareForClaimingEdit,
      isNot(en.expenseSaveAndShareForClaimingEdit),
    );

    expect(en.expenseDetailTitleEdit, 'Edit expense');
    expect(de.expenseDetailTitleEdit, 'Ausgabe bearbeiten');
  });

  // AC2 — the create-mode strings are the ones that still say "add".
  test('the create-mode labels are unchanged in both locales', () {
    expect(en.expenseAddButton, 'Add expense');
    expect(de.expenseAddButton, 'Ausgabe hinzufügen');
    expect(en.expenseSaveAndShareForClaiming, 'Add & share for claiming');
    expect(
      de.expenseSaveAndShareForClaiming,
      'Hinzufügen & zum Beanspruchen teilen',
    );
    expect(en.expenseDetailTitleNew, 'New expense');
    expect(de.expenseDetailTitleNew, 'Neue Ausgabe');
  });

  // AC4 — the callerless money/mode keys are gone from BOTH ARB files, and the
  // English template carries no orphaned @metadata for them either.
  test('callerless money/mode keys are deleted from both ARB files', () {
    final enArb = _arb('lib/l10n/app_en.arb');
    final deArb = _arb('lib/l10n/app_de.arb');

    for (final key in _deletedKeys) {
      expect(
        enArb.containsKey(key),
        isFalse,
        reason: '$key still in app_en.arb',
      );
      expect(
        enArb.containsKey('@$key'),
        isFalse,
        reason: '@$key metadata still in app_en.arb',
      );
      expect(
        deArb.containsKey(key),
        isFalse,
        reason: '$key still in app_de.arb',
      );
    }
  });

  // AC4 guard — the new key IS in both files, so the sweep did not overshoot.
  test('the new edit key exists in both ARB files', () {
    expect(
      _arb('lib/l10n/app_en.arb')['expenseSaveAndShareForClaimingEdit'],
      'Save & share for claiming',
    );
    expect(
      _arb('lib/l10n/app_de.arb')['expenseSaveAndShareForClaimingEdit'],
      'Speichern & zum Beanspruchen teilen',
    );
  });

  test('the rate copy is real German, not the English string copied over', () {
    expect(en.expenseRateReset, 'Reset');
    expect(de.expenseRateReset, 'Zurücksetzen');
    expect(en.expenseEntryCurrencyLabel, isNot(de.expenseEntryCurrencyLabel));
    expect(en.expenseRateRequired, isNot(de.expenseRateRequired));
  });

  test('the rate label names both currencies', () {
    expect(en.expenseRateLabel('JPY', 'EUR'), contains('JPY'));
    expect(en.expenseRateLabel('JPY', 'EUR'), contains('EUR'));
  });
}
