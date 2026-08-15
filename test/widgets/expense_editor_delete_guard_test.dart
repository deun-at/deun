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

Future<void> _pump(
  WidgetTester tester, {
  required Expense expense,
  List<Expense> paybacks = const [],
  Future<List<Expense>> Function(String groupId)? loader,
}) async {
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
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(
              group: _group(),
              expense: expense,
              loadGroupPaybacks: loader ?? (_) async => paybacks,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
}
