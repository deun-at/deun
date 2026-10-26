/// A receipt rescanned inside the editor (scan-total-applies).
///
/// The Scan pill lives in the Itemized header. A rescan that read only a total
/// used to re-seed the first item's seed alone: its form field kept the old
/// amount, so an empty item was refused on save and a filled one saved its old
/// amount while the row showed the scanned one.
library;

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/pages/expenses/presentation/receipt_scanner_sheet.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_editor_currency_rate_test.dart'
    show SavedExpense, installFakePrefs, pumpEditorWithSaveSeam, saveEditor;

Map<String, dynamic> _claimUnit(
  String id,
  String name,
  double amount,
  String itemGroupId, {
  double? originalAmount,
}) => {
  'id': id,
  'expense_id': 'exp1',
  'name': name,
  'amount': amount,
  'original_amount': originalAmount,
  'quantity': 1,
  'split_mode': 'claim',
  'item_group_id': itemGroupId,
  'created_at': '2026-07-01T10:00:00',
  'expense_entry_share': const [],
};

/// A saved shared expense with two items, Beer 2.50 and Wine 4.00. A claim
/// expense opens straight in the Itemized layout.
Expense _twoItemExpense() => Expense()
  ..loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': [
      _claimUnit('u1', 'Beer', 2.5, 'grp-1'),
      _claimUnit('u2', 'Wine', 4.0, 'grp-2'),
    ],
  }, currentUserEmail: null);

/// A saved shared expense entered in CHF inside a JPY group: one CHF 10.00
/// item at a frozen 160, so 1600 JPY in the ledger.
Expense _chfInJpyExpense() => Expense()
  ..loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'original_currency_code': 'CHF',
    'conversion_rate': 160.0,
    'rate_date': '2026-08-16',
    'expense_entry': [
      _claimUnit('u1', 'Beer', 1600, 'grp-1', originalAmount: 10),
    ],
  }, currentUserEmail: null);

/// A scanner answering each Scan tap with the next of [results].
ReceiptScanner _scans(List<ReceiptScanResult> results) {
  var next = 0;
  return (context) async => results[next++];
}

/// A total-only receipt. The merchant name fills the expense's required
/// description, so the save is refused only for the amount.
const _total4280 = ReceiptScanResult(merchantName: 'Billa', total: 42.80);

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// Pumps the editor over the shared save-capturing harness, with the scanner
/// stubbed. A null [scanReceipt] leaves the editor's own scanner in place; a
/// null [expense] opens a new one.
Future<List<SavedExpense>> _pumpEditor(
  WidgetTester tester, {
  Expense? expense,
  String currencyCode = 'EUR',
  ReceiptScanner? scanReceipt,
}) async {
  // Tall enough that every item row and the footer CTA are on screen.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final captured = await pumpEditorWithSaveSeam(
    tester,
    currencyCode: currencyCode,
    expense: expense,
    newExpense: expense == null,
    scanReceipt: scanReceipt,
  );
  // A new expense auto-opens the amount keypad (F100); dismiss it.
  if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
    await tester.pumpAndSettle();
  }
  return captured;
}

Future<void> _toItemized(WidgetTester tester) async {
  await tester.tap(find.text((await _l10n()).editorModeItemized));
  await tester.pumpAndSettle();
}

Future<void> _tapScan(WidgetTester tester) async {
  await tester.tap(find.text((await _l10n()).expenseScanShort));
  await tester.pumpAndSettle();
}

/// Retypes the first item's unit price, now reading [shown], as [digit]
/// through the row's own keypad.
Future<void> _retypeUnitPrice(
  WidgetTester tester,
  String shown,
  String digit,
) async {
  await tester.tap(find.text(shown));
  await tester.pumpAndSettle();
  expect(find.byType(AmountKeypadSheet), findsOneWidget);
  for (var i = 0; i < 6; i++) {
    await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
  }
  await tester.tap(find.byKey(ValueKey('keypad_$digit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
  await tester.pumpAndSettle();
}

/// Every item the save carries, as (name, entered amount), in item order.
List<(String?, double)> _savedItems(SavedExpense saved) => [
  for (final line in saved.draft.entries) (line.name, line.unitPrice),
];

Finder get _headerClose => find.descendant(
  of: find.byType(DeunHeader),
  matching: find.byIcon(Icons.close),
);

void main() {
  setUp(installFakePrefs);

  testWidgets('a total-only rescan fills an item that has no amount yet', (
    tester,
  ) async {
    final saved = await _pumpEditor(tester, scanReceipt: _scans([_total4280]));
    final l10n = await _l10n();
    await _toItemized(tester);

    await _tapScan(tester);

    expect(find.text('42.80'), findsOneWidget, reason: 'the unit price');
    expect(
      find.text(l10n.toCurrency(42.8)),
      findsNWidgets(2),
      reason: 'the line total and the itemized total',
    );
    await saveEditor(tester);
    expect(saved, hasLength(1), reason: 'the save must not be refused');
    expect(_savedItems(saved.single).map((i) => i.$2), [42.8]);
  });

  testWidgets(
    'a total-only rescan onto a multi-unit item stores the total, not total x units',
    (tester) async {
      final saved = await _pumpEditor(
        tester,
        scanReceipt: _scans([
          const ReceiptScanResult(
            lineItems: [ReceiptLineItem(name: 'Pita', amount: 12, quantity: 3)],
          ),
          _total4280,
        ]),
      );
      final l10n = await _l10n();
      await _toItemized(tester);
      await _tapScan(tester);
      expect(find.text('4.00'), findsOneWidget, reason: 'control: 3 x 4.00');

      await _tapScan(tester);

      expect(find.text('42.80'), findsOneWidget, reason: 'the unit price');
      expect(
        find.text(l10n.toCurrency(42.8)),
        findsNWidgets(2),
        reason: 'the line total and the itemized total, not 128.40',
      );
      await saveEditor(tester);
      expect(_savedItems(saved.single).map((i) => i.$2), [42.8]);
      expect(
        saved.single.draft.entries.map((line) => line.quantity.toString()),
        ['1'],
      );
    },
  );

  testWidgets(
    'rescanning the same total replaces the amount the user typed over it',
    (tester) async {
      final saved = await _pumpEditor(
        tester,
        scanReceipt: _scans([_total4280, _total4280]),
      );
      final l10n = await _l10n();
      await _toItemized(tester);
      await _tapScan(tester);
      await _retypeUnitPrice(tester, '42.80', '5');
      expect(
        find.text(l10n.toCurrency(5)),
        findsNWidgets(2),
        reason: 'control',
      );

      await _tapScan(tester);

      expect(find.text('42.80'), findsOneWidget, reason: 'the row adopts it');
      expect(find.text('5.00'), findsNothing);
      expect(find.text(l10n.toCurrency(42.8)), findsNWidgets(2));
      await saveEditor(tester);
      expect(_savedItems(saved.single).map((i) => i.$2), [42.8]);
    },
  );

  testWidgets(
    'the total is written at the ENTRY currency precision, not the group one',
    (tester) async {
      final saved = await _pumpEditor(
        tester,
        expense: _chfInJpyExpense(),
        currencyCode: 'JPY',
        scanReceipt: _scans([const ReceiptScanResult(total: 12.34)]),
      );
      expect(find.text('10.00'), findsOneWidget, reason: 'control');

      await _tapScan(tester);

      expect(find.text('12.34'), findsOneWidget);
      expect(find.text('10.00'), findsNothing);
      await saveEditor(tester);
      final payload = saved.single;
      expect(payload.draft.entries[0].unitPrice, 12.34);
      expect(payload.conversion!.entryCurrency, Currency.chf);
      expect(payload.currency, Currency.jpy);
    },
  );

  testWidgets('with every item removed, a total-only rescan adds one item', (
    tester,
  ) async {
    final saved = await _pumpEditor(tester, scanReceipt: _scans([_total4280]));
    await _toItemized(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ExpenseEntryWidget),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseEntryWidget), findsNothing, reason: 'control');

    await _tapScan(tester);

    expect(find.byType(ExpenseEntryWidget), findsOneWidget);
    expect(find.text('42.80'), findsOneWidget);
    await saveEditor(tester);
    expect(_savedItems(saved.single).map((i) => i.$2), [42.8]);
  });

  testWidgets(
    'with two items, a total-only rescan changes only the first amount',
    (tester) async {
      final saved = await _pumpEditor(
        tester,
        expense: _twoItemExpense(),
        scanReceipt: _scans([const ReceiptScanResult(total: 42.80)]),
      );

      await _tapScan(tester);
      await saveEditor(tester);

      expect(_savedItems(saved.single), [('Beer', 42.8), ('Wine', 4.0)]);
    },
  );

  testWidgets('a total-only rescan arms the discard confirmation', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      expense: _twoItemExpense(),
      scanReceipt: _scans([const ReceiptScanResult(total: 42.80)]),
    );
    final l10n = await _l10n();

    await _tapScan(tester);
    await tester.tap(_headerClose);
    await tester.pumpAndSettle();

    expect(find.text(l10n.discardChangesTitle), findsOneWidget);
    expect(find.text('BEHIND'), findsNothing);
  });

  testWidgets('a total-only rescan still applies the merchant name and date', (
    tester,
  ) async {
    final saved = await _pumpEditor(
      tester,
      expense: _twoItemExpense(),
      scanReceipt: _scans([
        ReceiptScanResult(
          merchantName: 'Billa',
          date: DateTime(2026, 10, 20),
          total: 42.80,
        ),
      ]),
    );

    await _tapScan(tester);
    await saveEditor(tester);

    expect(saved.single.draft.name, 'Billa');
    expect(saved.single.draft.expenseDate, DateTime(2026, 10, 20));
  });

  testWidgets('a line-item rescan replaces the items with the scanned lines', (
    tester,
  ) async {
    final saved = await _pumpEditor(
      tester,
      expense: _twoItemExpense(),
      scanReceipt: _scans([
        const ReceiptScanResult(
          lineItems: [
            ReceiptLineItem(name: 'Pita', amount: 12.50),
            ReceiptLineItem(name: 'Zhug', amount: 2.00),
          ],
        ),
      ]),
    );

    await _tapScan(tester);
    await saveEditor(tester);

    expect(_savedItems(saved.single), [('Pita', 12.5), ('Zhug', 2.0)]);
  });

  testWidgets('Scan in the Itemized header opens the receipt scanner', (
    tester,
  ) async {
    await _pumpEditor(tester);
    await _toItemized(tester);

    await _tapScan(tester);

    expect(find.byType(ReceiptScannerSheet), findsOneWidget);
  });
}
