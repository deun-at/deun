import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expense_save_status_test.dart'
    show cta, drainSnackBar, headerClose, nameField, openDateSheetMidWrite;

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
  g.simplifiedExpenses = true;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

/// A saved quick expense as `fetchDetail` returns it: one equal-split entry
/// shared between both members.
Expense _quickExpense({String date = '2026-01-10'}) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'e1',
    'group_id': 'g1',
    'name': 'Dinner',
    'expense_date': date,
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

/// A payback row dated [date], shaped the way `pay_back` writes one.
Expense _payback(String date) {
  final share = ExpenseEntryShare();
  share.expenseEntryId = 'pe1';
  share.email = 'b@test.com';
  share.displayName = 'Bob';
  share.percentage = 100;
  share.fixedAmount = null;
  share.parts = null;
  share.isLocked = false;
  share.createdAt = '';

  final entry = ExpenseEntry(index: 0)
    ..id = 'pe1'
    ..expenseId = 'p1'
    ..name = 'paid_back'
    ..amount = 12.5
    ..quantity = 1
    ..splitMode = 'equal'
    ..createdAt = ''
    ..expenseEntryShares = [share];

  final e = Expense();
  e.id = 'p1';
  e.groupId = 'g1';
  e.name = 'paid_back';
  e.amount = 12.5;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = date;
  e.createdAt = '';
  e.isPaidBackRow = true;
  e.category = null;
  e.groupMemberShareStatistic = const {'b@test.com': 12.5};
  e.expenseEntries = {'pe1': entry};
  return e;
}

/// Records every delete the editor issues. [gate] holds the write open, so the
/// in-flight window is observable; [throws] makes it fail.
class _Deleter {
  _Deleter({this.throws, this.gate});

  final Object? throws;
  final Completer<void>? gate;
  final calls = <(String, String)>[];

  Future<void> call(String expenseId, String groupId) async {
    calls.add((expenseId, groupId));
    if (gate != null) await gate!.future;
    final failure = throws;
    if (failure != null) throw failure;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Expense expense,
  List<Expense> paybacks = const [],
  Future<List<Expense>> Function(String groupId)? loader,
  _Deleter? deleter,
  List<Map<String, dynamic>>? saves,
}) async {
  final deletes = deleter ?? _Deleter();
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
        // '/edit' builds the stack ['/', '/edit'], so a successful delete's
        // pop has somewhere to land instead of emptying the navigator.
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
              expense: expense,
              loadGroupPaybacks: loader ?? (_) async => paybacks,
              deleteExpense: deletes.call,
              saveExpense:
                  (
                    context,
                    groupId,
                    expenseId,
                    formResponse, {
                    required currency,
                    conversion,
                  }) async {
                    saves?.add(Map<String, dynamic>.from(formResponse));
                  },
            ),
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the confirmation and taps its Delete. The caller pumps.
Future<void> _confirmDelete(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(_headerDelete);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(l10n.delete),
    ),
  );
}

/// The delete action in the editor header (the item cards have their own trash).
Finder get _headerDelete => find.descendant(
  of: find.byType(DeunHeader),
  matching: find.byIcon(Icons.delete_outline),
);

/// The header delete `IconButton` itself, found by type rather than its icon
/// — needed to re-tap it while a probe is in flight, when the icon has
/// already been swapped for a progress indicator.
Finder get _headerDeleteButton => find.descendant(
  of: find.byType(DeunHeader),
  matching: find.byType(IconButton),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  // 17 — no regression: the editor's unguarded dialog is today's single string.
  testWidgets('the editor unguarded delete dialog shows today plain prompt', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _quickExpense());

    await tester.tap(_headerDelete);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.expenseDeleteItemTitle), findsOneWidget);
    expect(find.text(l10n.expenseDeleteSettledTitle), findsNothing);
  });

  // 18 — guarded, and cancelling writes nothing.
  testWidgets(
    'the editor warns on a settled expense, and cancel writes nothing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        expense: _quickExpense(date: '2026-01-10'),
        // Same day as the expense — the inclusive side of the boundary.
        paybacks: [_payback('2026-01-10')],
      );

      await tester.tap(_headerDelete);
      await tester.pumpAndSettle();

      // One dialog, not two, and its single body carries both halves.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining(l10n.expenseDeleteSettledTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.expenseDeleteSettledMessage(1)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      // Dialog closed, editor still open on the expense, nothing written.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
      expect(find.text(l10n.expenseDeleteError), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // 19 — the exclusive side of the boundary, through the real widget.
  testWidgets(
    'a payback dated before the expense leaves the editor dialog plain',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        expense: _quickExpense(date: '2026-01-10'),
        paybacks: [_payback('2026-01-09')],
      );

      await tester.tap(_headerDelete);
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseDeleteItemTitle), findsOneWidget);
      expect(find.textContaining(l10n.expenseDeleteSettledTitle), findsNothing);
    },
  );

  // 20 — the probe is skipped entirely when the row being deleted IS a
  // settlement: classifyExpenseDeletion never reads the group's other rows in
  // that branch, so fetching them first would be a wasted round-trip.
  testWidgets('deleting a payback row never probes the group', (tester) async {
    var loadCalls = 0;
    await _pump(
      tester,
      expense: _payback('2026-01-10'),
      loader: (_) async {
        loadCalls++;
        return const [];
      },
    );

    await tester.tap(_headerDelete);
    await tester.pumpAndSettle();

    expect(loadCalls, 0);
  });

  // 21 — the bug fix: a slow/hanging probe must not leave the header delete
  // action tappable, or a repeat tap would start a second probe and, once
  // both resolve, stack a second AlertDialog on top of the first.
  testWidgets(
    'the header delete action shows progress and ignores a second tap while the probe is in flight',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      var loadCalls = 0;
      final completer = Completer<List<Expense>>();
      await _pump(
        tester,
        expense: _quickExpense(),
        loader: (_) {
          loadCalls++;
          return completer.future;
        },
      );

      await tester.tap(_headerDelete);
      await tester.pump();

      // Probe in flight: the delete icon is replaced by progress, and the
      // dialog has not appeared yet.
      expect(_headerDelete, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(loadCalls, 1);

      // A second tap on the same header button while busy must be a no-op —
      // its onPressed is null while the probe is in flight.
      await tester.tap(_headerDeleteButton);
      await tester.pump();
      expect(loadCalls, 1);

      completer.complete(const []);
      await tester.pumpAndSettle();

      // Exactly one dialog appears once the single probe resolves.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.expenseDeleteItemTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed delete keeps the editor and its edits, and a later save sends them',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final deleter = _Deleter(throws: Exception('offline'));
      final saves = <Map<String, dynamic>>[];
      await _pump(
        tester,
        expense: _quickExpense(),
        deleter: deleter,
        saves: saves,
      );

      await tester.enterText(nameField, 'Dinner for two');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await _confirmDelete(tester, l10n);
      await tester.pumpAndSettle();

      expect(deleter.calls, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('BEHIND'), findsNothing);
      expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
      expect(find.text('Dinner for two'), findsOneWidget);
      expect(find.text(l10n.expenseDeleteError), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
      // The header delete is back for a retry.
      expect(_headerDelete, findsOneWidget);
      expect(
        tester.widget<IconButton>(_headerDeleteButton).onPressed,
        isNotNull,
      );

      // Drain the error SnackBar (it would sit over the CTA), then save.
      await drainSnackBar(tester);
      await tester.tap(cta);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(saves, hasLength(1));
      expect(saves.single['name'], 'Dinner for two');
      expect(find.text('BEHIND'), findsOneWidget);
    },
  );

  testWidgets(
    'a confirmed delete removes this expense once and closes the editor',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final deleter = _Deleter();
      await _pump(tester, expense: _quickExpense(), deleter: deleter);

      await _confirmDelete(tester, l10n);
      await tester.pumpAndSettle();

      expect(deleter.calls, [('e1', 'g1')]);
      expect(find.text(l10n.expenseDeleteSuccess), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ExpenseDetail), findsNothing);
      expect(find.text('BEHIND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // The header spinner animates forever, so this test pumps explicitly until
  // the gate opens.
  testWidgets(
    'while a confirmed delete runs, neither delete nor save starts a second write',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final gate = Completer<void>();
      final deleter = _Deleter(gate: gate);
      final saves = <Map<String, dynamic>>[];
      await _pump(
        tester,
        expense: _quickExpense(),
        deleter: deleter,
        saves: saves,
      );

      await _confirmDelete(tester, l10n);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog exit

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DeunHeader),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'the header shows progress for the delete write',
      );

      await tester.tap(_headerDeleteButton);
      await tester.pump();
      await tester.tap(cta);
      await tester.pump();

      expect(deleter.calls, hasLength(1));
      expect(saves, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseDetail), findsNothing);
      // Popped once: a second pop would have taken '/' with it.
      expect(find.text('BEHIND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // The delete write runs with the editor uncovered, and its sheets open on
  // the editor's own (root) navigator: the success pop must close the editor,
  // not the sheet on top of it.
  testWidgets(
    'a delete that succeeds under an open sheet still closes the editor',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final gate = Completer<void>();
      await _pump(
        tester,
        expense: _quickExpense(),
        deleter: _Deleter(gate: gate),
      );

      await _confirmDelete(tester, l10n);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog exit
      await openDateSheetMidWrite(tester);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseDetail), findsNothing);
      expect(find.text('BEHIND'), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSuccess), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // The close button and system back go through PopScope, which a delete in
  // flight must refuse: the editor stays until the write answers, so a failure
  // can still be reported and a success pops the editor, not a discard sheet.
  for (final dirty in [false, true]) {
    testWidgets(
      'closing is refused while a confirmed delete runs (${dirty ? 'dirty' : 'clean'} form), then it closes once',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final gate = Completer<void>();
        final deleter = _Deleter(gate: gate);
        await _pump(tester, expense: _quickExpense(), deleter: deleter);

        if (dirty) {
          await tester.enterText(nameField, 'Dinner for two');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }

        await _confirmDelete(tester, l10n);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // dialog exit

        await tester.tap(headerClose);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(l10n.discardChangesTitle), findsNothing);
        expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
        expect(find.text('BEHIND'), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.byType(ExpenseDetail), findsNothing);
        expect(find.text(l10n.discardChangesTitle), findsNothing);
        expect(find.text('BEHIND'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dismissing the confirmation with a barrier tap deletes nothing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final deleter = _Deleter();
      await _pump(tester, expense: _quickExpense(), deleter: deleter);

      await tester.tap(_headerDelete);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // the modal barrier
      await tester.pumpAndSettle();

      expect(deleter.calls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
      expect(find.text('BEHIND'), findsNothing);
    },
  );

  testWidgets(
    'after a failed delete, closing the editor still asks to discard',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        expense: _quickExpense(),
        deleter: _Deleter(throws: Exception('offline')),
      );

      await tester.enterText(nameField, 'Dinner for two');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await _confirmDelete(tester, l10n);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(headerClose);
      await tester.pumpAndSettle();

      expect(find.text(l10n.discardChangesTitle), findsOneWidget);
      expect(find.text('BEHIND'), findsNothing);
    },
  );
}
