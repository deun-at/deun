/// The expense editor's save confirmation lives on the CTA, not in a snackbar.
///
/// Before this, `_saveExpense` popped the route in a `finally` and *then* called
/// `showSnackBar`, so "Expense created!" landed on the screen the user had
/// already navigated back to — and nothing at all marked the save as in flight,
/// so a second tap could fire a second write. The CTA now carries all three
/// states: idle, busy, done.
library;

import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/helper/currency.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expense_editor_currency_rate_test.dart'
    show initTestSupabase, installFakePrefs;

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
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.currencyCode = 'EUR';
  g.simplifiedExpenses = true;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

/// A saved quick expense: one equal-split entry, so the editor opens Quick.
Expense _quickExpense() {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'e1',
    'group_id': 'g1',
    'name': 'Dinner',
    'expense_date': '2026-01-10',
    'paid_by': 'a@test.com',
    'created_at': '2026-01-10T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': [
      {
        'id': 'ee1',
        'expense_id': 'e1',
        'name': 'Dinner',
        'amount': 20.0,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2026-01-10T10:00:00',
        'expense_entry_share': [
          {
            'expense_entry_id': 'ee1',
            'email': 'a@test.com',
            'display_name': 'Alice',
            'percentage': 50.0,
            'created_at': '2026-01-10T10:00:00',
          },
          {
            'expense_entry_id': 'ee1',
            'email': 'b@test.com',
            'display_name': 'Bob',
            'percentage': 50.0,
            'created_at': '2026-01-10T10:00:00',
          },
        ],
      },
    ],
  });
  return e;
}

/// A save the test holds open, so the in-flight state is observable.
class _GatedSave {
  final gate = Completer<void>();
  final Object? throwing;
  int calls = 0;

  _GatedSave({this.throwing});

  Future<void> call(
    BuildContext context,
    String groupId,
    String? expenseId,
    Map<String, dynamic> formResponse, {
    required Currency currency,
    ExpenseConversion? conversion,
  }) async {
    calls++;
    await gate.future;
    if (throwing != null) throw throwing!;
  }
}

Future<void> _pumpEditor(WidgetTester tester, _GatedSave save) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // '/edit' builds the stack ['/', '/edit'] so the post-save pop has
        // somewhere to land instead of emptying the navigator.
        initialRoute: '/edit',
        routes: {
          '/': (context) => const Scaffold(body: Text('BEHIND')),
          '/edit': (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(
              group: _group(),
              expense: _quickExpense(),
              saveExpense: save.call,
            ),
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _cta => find.byType(PrimaryButton).last;

void main() {
  setUpAll(initTestSupabase);

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(installFakePrefs);

  testWidgets('the CTA spins while the save is in flight', (tester) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a second tap while busy does not fire a second write', (
    tester,
  ) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();
    await tester.tap(_cta, warnIfMissed: false);
    await tester.pump();

    expect(save.calls, 1);

    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the check lands on the CTA before the route pops', (
    tester,
  ) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();
    save.gate.complete();
    await tester.pump(); // save resolves, status flips to done
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      find.text('BEHIND'),
      findsNothing,
      reason: 'the editor must still be on screen while the check shows',
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('no "Expense created!" snackbar — the check replaced it', (
    tester,
  ) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();
    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Expense created!'), findsNothing);
  });

  testWidgets('the route still pops once the confirmation has been seen', (
    tester,
  ) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();
    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('BEHIND'), findsOneWidget);
  });

  testWidgets('a failed save shows the error and never shows a check', (
    tester,
  ) async {
    final save = _GatedSave(throwing: Exception('offline'));
    await _pumpEditor(tester, save);

    await tester.tap(_cta);
    await tester.pump();
    save.gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
