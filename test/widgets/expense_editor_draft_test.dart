// typed-expense-draft: the editor hands the save what is on screen. Every test
// drives the real editor and reads the ExpenseDraft its save seam receives.
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expense_editor_currency_rate_test.dart'
    show initTestSupabase, installFakePrefs, pumpEditorWithSaveSeam, saveEditor;

const _a = 'a@test.com';
const _b = 'b@test.com';

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

Map<String, dynamic> _share(
  String entryId,
  String email, {
  required double percentage,
  double? fixedAmount,
  bool isLocked = false,
}) => {
  'expense_entry_id': entryId,
  'email': email,
  'display_name': email == _a ? 'Alice' : 'Bob',
  'percentage': percentage,
  'fixed_amount': fixedAmount,
  'is_locked': isLocked,
  'created_at': '2026-07-01T10:00:00',
};

/// A saved EUR expense in the harness group (Alice, Bob) with [entries].
Expense _expense(List<Map<String, dynamic>> entries) =>
    Expense()..loadDataFromJson({
      'id': 'exp1',
      'group_id': 'g1',
      'name': 'Dinner',
      'expense_date': '2026-07-01',
      'paid_by': _a,
      'created_at': '2026-07-01T10:00:00',
      'is_paid_back_row': false,
      'expense_entry': entries,
    });

/// A Quick 12.50 split exact 4.00 / 8.50, Alice's amount locked.
Expense _quickExactLocked() => _expense([
  {
    'id': 'u1',
    'expense_id': 'exp1',
    'name': 'Dinner',
    'amount': 12.5,
    'quantity': 1,
    'split_mode': 'exact',
    'created_at': '2026-07-01T10:00:00',
    'expense_entry_share': [
      _share('u1', _a, percentage: 32, fixedAmount: 4.0, isLocked: true),
      _share('u1', _b, percentage: 68, fixedAmount: 8.5),
    ],
  },
]);

Map<String, dynamic> _beerUnit(String id, List<String> claimers) => {
  'id': id,
  'expense_id': 'exp1',
  'name': 'Beer',
  'amount': 5.0,
  'quantity': 1,
  'split_mode': 'claim',
  'item_group_id': 'grp-1',
  'created_at': '2026-07-01T10:00:00',
  'expense_entry_share': [
    for (final email in claimers)
      _share(id, email, percentage: 100 / claimers.length),
  ],
};

/// A shared 3x Beer whose units are claimed by Alice, by Bob, and by both.
Expense _claimedBeer() => _expense([
  _beerUnit('u1', [_a]),
  _beerUnit('u2', [_b]),
  _beerUnit('u3', [_a, _b]),
]);

void main() {
  setUpAll(initTestSupabase);

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(installFakePrefs);

  testWidgets(
    'an itemized save hands over the lines on screen, in order, without a removed one',
    (tester) async {
      // Tall enough that every item row and the footer CTA are on screen.
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final l10n = await _l10n();
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        newExpense: true,
        scanReceipt: (context) async => const ReceiptScanResult(
          merchantName: 'Billa',
          lineItems: [
            ReceiptLineItem(name: 'Pita', amount: 12.50),
            ReceiptLineItem(name: 'Zhug', amount: 2.00),
            ReceiptLineItem(name: 'Beer', amount: 3.00, quantity: 2),
          ],
        ),
      );
      // A new expense auto-opens the amount keypad (F100); dismiss it.
      if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.editorModeItemized));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.expenseScanShort));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Zhug'),
            matching: find.byType(ExpenseEntryWidget),
          ),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      await saveEditor(tester);

      expect(saved, hasLength(1));
      expect(
        [
          for (final line in saved.single.draft.entries)
            (line.name, line.unitPrice, line.quantity),
        ],
        [('Pita', 12.5, 1), ('Beer', 1.5, 2)],
      );
    },
  );

  testWidgets(
    'a quick save hands over the split mode, per-member values and locked members',
    (tester) async {
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: _quickExactLocked(),
      );

      await saveEditor(tester);

      final line = saved.single.draft.entries.single;
      expect(line.unitPrice, 12.5);
      expect(line.splitMode, SplitMode.amount);
      expect(line.shares, {_a, _b});
      expect(line.shareData, {_a: 4.0, _b: 8.5});
      expect(line.lockedMembers, {_a});
    },
  );

  testWidgets('a shares split hands over whole-number parts', (tester) async {
    final l10n = await _l10n();
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      initialAmount: 12.5,
    );
    await tester.ensureVisible(find.text(l10n.splitModeShares));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.splitModeShares));
    await tester.pumpAndSettle();

    await saveEditor(tester);

    final line = saved.single.draft.entries.single;
    expect(line.splitMode, SplitMode.shares);
    expect(line.shareData, {_a: 1, _b: 1});
    // The payload's `parts` lands in an integer column: 1, never 1.0.
    expect(line.shareData.values, everyElement(isA<int>()));
  });

  testWidgets('a claimable re-save hands each card its existing claims', (
    tester,
  ) async {
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      expense: _claimedBeer(),
    );

    await saveEditor(tester);

    final line = saved.single.draft.entries.single;
    expect(line.claimable, isTrue);
    expect(line.quantity, 3);
    expect(line.existingClaims, [
      [_a],
      [_b],
      [_a, _b],
    ]);
    expect(line.shares, {
      _a,
      _b,
    }, reason: 'every active member hears there is something to claim');
  });

  testWidgets(
    'an amount that does not parse ends in the save error, the CTA idle and nothing written',
    (tester) async {
      final l10n = await _l10n();
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        initialAmount: 12.5,
      );
      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      final amountField = form.fields.keys.singleWhere(
        (name) => name.endsWith('[amount]'),
      );
      form.fields[amountField]!.didChange('1,50');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pumpAndSettle();

      expect(saved, isEmpty, reason: 'the saver is never called');
      expect(find.text(l10n.expenseCreateError), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PrimaryButton).last,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text('BEHIND'), findsNothing, reason: 'the editor stays');

      await tester.pumpAndSettle(const Duration(seconds: 5));
    },
  );
}
