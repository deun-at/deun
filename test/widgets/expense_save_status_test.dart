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
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_draft.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_editor_currency_rate_test.dart'
    show
        SavedExpense,
        closeConversionSheet,
        installFakePrefs,
        openConversionSheet,
        pickCurrency;

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
  }, currentUserEmail: null);
  return e;
}

/// A save the test holds open, so the in-flight state is observable. Records
/// every payload, so a retry can be compared with the attempt it repeats.
class _GatedSave {
  final gate = Completer<void>();
  final Object? throwing;

  /// How many leading calls throw [throwing]; later calls succeed. Null: every
  /// call throws.
  final int? failures;

  final payloads = <SavedExpense>[];

  _GatedSave({this.throwing, this.failures});

  int get calls => payloads.length;

  Future<void> call(
    String groupId,
    String? expenseId,
    ExpenseDraft draft, {
    required Currency currency,
    ExpenseConversion? conversion,
    required NotificationSender notifications,
  }) async {
    payloads.add(SavedExpense(draft, currency, conversion));
    await gate.future;
    final failing = failures == null || payloads.length <= failures!;
    if (throwing != null && failing) throw throwing!;
  }
}

/// Remembering the typed rate fails after the expense write has committed.
class _FailingStickyRate extends StickyRateNotifier {
  int setCalls = 0;

  @override
  Future<void> setStickyRate(String groupId, Currency from, double rate) async {
    setCalls++;
    throw Exception('disk full');
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  _GatedSave save, {
  StickyRateNotifier Function()? stickyRate,
  Future<void> Function(String expenseId, String groupId)? deleteExpense,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        if (stickyRate != null) stickyRateProvider.overrideWith(stickyRate),
      ],
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
              deleteExpense: deleteExpense,
              // A foreign-currency pick fires the prefill; never let it reach
              // the real rate source from a widget test.
              lookupRate:
                  ({required base, required quote, required date}) async =>
                      null,
            ),
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get cta => find.byType(PrimaryButton).last;

Finder get nameField => find.byKey(const ValueKey('expense_name_field'));

Finder get headerClose => find.descendant(
  of: find.byType(DeunHeader),
  matching: find.byIcon(Icons.close),
);

/// Retypes the Quick amount through its keypad: the seeded 20 → 35.
Future<void> _typeAmount35(WidgetTester tester) async {
  await tester.tap(find.text('20.00')); // the Quick hero amount
  await tester.pumpAndSettle();
  expect(find.byType(AmountKeypadSheet), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
  await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
  await tester.tap(find.byKey(const ValueKey('keypad_3')));
  await tester.tap(find.byKey(const ValueKey('keypad_5')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
  await tester.pumpAndSettle();
}

/// Lets a SnackBar run its whole life. Its 2s timer starts only once the
/// entrance animation ends and is not a frame, so settling alone leaves it
/// on screen, over the CTA.
Future<void> drainSnackBar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Opens the date sheet over the editor while a write is out. Explicit pumps:
/// the in-flight spinner never settles.
Future<void> openDateSheetMidWrite(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.ensureVisible(find.text(l10n.expenseWhen));
  await tester.pump();
  await tester.tap(find.text(l10n.expenseWhen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500)); // sheet entrance
  expect(find.byType(DateOptionsSheet), findsOneWidget);
}

/// Picks CHF and types a rate, which makes the rate the user's own.
Future<void> _enterChfAtTypedRate(WidgetTester tester) async {
  await pickCurrency(tester, 'CHF');
  await openConversionSheet(tester);
  await tester.enterText(
    find.byKey(const ValueKey('expense_rate_field')),
    '0.95',
  );
  await tester.pumpAndSettle();
  await closeConversionSheet(tester);
}

void main() {
  setUp(installFakePrefs);

  testWidgets('the CTA spins while the save is in flight', (tester) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(cta);
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

    await tester.tap(cta);
    await tester.pump();
    await tester.tap(cta, warnIfMissed: false);
    await tester.pump();

    expect(save.calls, 1);

    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('while a save is out, the header delete and close do nothing', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deletes = <String>[];
    final save = _GatedSave();
    await _pumpEditor(
      tester,
      save,
      deleteExpense: (expenseId, groupId) async => deletes.add(expenseId),
    );

    await tester.tap(cta);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(DeunHeader),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pump();
    await tester.tap(headerClose);
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(deletes, isEmpty);
    expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
    expect(find.text('BEHIND'), findsNothing);

    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('BEHIND'), findsOneWidget);
  });

  testWidgets('the check lands on the CTA before the route pops', (
    tester,
  ) async {
    final save = _GatedSave();
    await _pumpEditor(tester, save);

    await tester.tap(cta);
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

    await tester.tap(cta);
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

    await tester.tap(cta);
    await tester.pump();
    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('BEHIND'), findsOneWidget);
  });

  // The date sheet opens on the same root navigator as the editor's route, so
  // the success pop must close the editor, not whatever sits on top of it.
  testWidgets(
    'a save that succeeds under an open sheet still closes the editor',
    (tester) async {
      final save = _GatedSave();
      await _pumpEditor(tester, save);

      await tester.tap(cta);
      await tester.pump();
      await openDateSheetMidWrite(tester);

      save.gate.complete();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(DateOptionsSheet), findsNothing);
      expect(find.byType(ExpenseDetail), findsNothing);
      expect(find.text('BEHIND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed save shows the error and never shows a check', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final save = _GatedSave(throwing: Exception('offline'));
    await _pumpEditor(tester, save);

    await tester.tap(cta);
    await tester.pump();
    save.gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // Settle the SnackBar's entrance; its 2s timer is not a frame, so it is
    // still on screen here.
    await tester.pumpAndSettle();
    expect(find.text(l10n.expenseCreateError), findsOneWidget);
    expect(
      find.text('BEHIND'),
      findsNothing,
      reason: 'a failed write must not close the editor',
    );
    // Back to idle: no spinner on the CTA.
    expect(
      find.descendant(
        of: cta,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets(
    'a retry after a failed save sends the same name, amount and conversion',
    (tester) async {
      final save = _GatedSave(throwing: Exception('offline'), failures: 1);
      save.gate.complete();
      await _pumpEditor(tester, save);

      await tester.enterText(nameField, 'Lunch');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _typeAmount35(tester);
      await _enterChfAtTypedRate(tester);

      await tester.tap(cta);
      await drainSnackBar(tester);
      expect(save.calls, 1, reason: 'one tap, one write');

      await tester.tap(cta);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(save.calls, 2, reason: 'one tap, one write');
      expect(find.text('BEHIND'), findsOneWidget);

      final first = save.payloads[0];
      final second = save.payloads[1];
      expect(first.draft.name, 'Lunch');
      expect(first.enteredAmount(0), 35);
      expect(first.conversion!.entryCurrency, Currency.chf);
      expect(first.conversion!.rate, 0.95);
      expect(first.conversion!.rateDate, isNotNull);
      expect(second.draft, first.draft);
      expect(
        second.conversion!.expenseProvenance,
        first.conversion!.expenseProvenance,
      );
    },
  );

  testWidgets(
    'a failed rate memory after a committed write still counts as saved',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final sticky = _FailingStickyRate();
      final save = _GatedSave();
      await _pumpEditor(tester, save, stickyRate: () => sticky);
      await _enterChfAtTypedRate(tester);

      await tester.tap(cta);
      await tester.pump();
      save.gate.complete();
      await tester.pump();
      await tester.pump();

      expect(
        sticky.setCalls,
        1,
        reason: 'the typed rate was offered to the store',
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text(l10n.expenseCreateError), findsNothing);

      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('BEHIND'), findsOneWidget);
      expect(save.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('after a failed save, closing the editor still asks to discard', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final save = _GatedSave(throwing: Exception('offline'));
    save.gate.complete();
    await _pumpEditor(tester, save);

    await tester.enterText(nameField, 'Lunch');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(cta);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(headerClose);
    await tester.pumpAndSettle();

    expect(find.text(l10n.discardChangesTitle), findsOneWidget);
    expect(find.text('BEHIND'), findsNothing);
  });
}
