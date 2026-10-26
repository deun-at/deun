import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Group _group() {
  final g = Group();
  g.id = 'g1';
  g.name = 'Dinner';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.currencyCode = 'EUR';
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

Future<void> _pumpEditor(WidgetTester tester, ReceiptScanResult receipt) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(null)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(
              group: _group(),
              expense: null,
              receiptResult: receipt,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
    await tester.pumpAndSettle();
  }
}

/// The seeded (unit price, quantity) of every item row, in form order.
List<(String, String)> _seededLines(WidgetTester tester) {
  final values = tester
      .state<FormBuilderState>(find.byType(FormBuilder))
      .instantValue;
  final indexes =
      values.keys
          .map(
            (k) => RegExp(r'^expense_entry\[(\d+)\]\[amount\]$').firstMatch(k),
          )
          .whereType<RegExpMatch>()
          .map((m) => int.parse(m.group(1)!))
          .toList()
        ..sort();
  return [
    for (final i in indexes)
      (
        values['expense_entry[$i][amount]'].toString(),
        values['expense_entry[$i][quantity]'].toString(),
      ),
  ];
}

void main() {
  testWidgets(
    'a scanned multi-unit line keeps its quantity and seeds the unit price',
    (tester) async {
      await _pumpEditor(
        tester,
        const ReceiptScanResult(
          merchantName: 'NENI am Prater',
          lineItems: [
            ReceiptLineItem(name: 'Pita', amount: 12.50, quantity: 5),
            ReceiptLineItem(name: 'Risotto', amount: 55.00, quantity: 2),
            ReceiptLineItem(name: 'Zhug', amount: 2.00),
          ],
        ),
      );

      expect(_seededLines(tester), [
        ('2.50', '5'),
        ('27.50', '2'),
        ('2.00', '1'),
      ]);
    },
  );

  testWidgets(
    'a line total that does not split evenly keeps the digits that multiply '
    'back to it',
    (tester) async {
      await _pumpEditor(
        tester,
        const ReceiptScanResult(
          lineItems: [
            ReceiptLineItem(name: 'Coffee', amount: 10.00, quantity: 3),
          ],
        ),
      );

      final [(unit, qty)] = _seededLines(tester);
      expect(qty, '3');
      expect(
        (double.parse(unit) * 3 * 100).round(),
        1000,
        reason: 'unit "$unit" × 3 must give back the scanned 10.00',
      );
    },
  );
}
