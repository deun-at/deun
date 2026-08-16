import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
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

ExpenseEntry _entry(int index, {String splitMode = 'equal'}) =>
    ExpenseEntry(index: index)
      ..splitMode = splitMode
      ..quantity = 1;

Expense _expense({
  required int entryCount,
  required Map<String, double> shareStat,
  double amount = 30,
  String paidBy = 'a@test.com',
  ExpenseCategory? category = ExpenseCategory.food,
  String entrySplitMode = 'equal',
}) {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = amount;
  e.paidBy = paidBy;
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = category;
  e.groupMemberShareStatistic = shareStat;
  e.expenseEntries = {
    for (var i = 0; i < entryCount; i++)
      'entry$i': _entry(i, splitMode: entrySplitMode),
  };
  return e;
}

/// A payback row as `pay_back` writes one: a single entry with a single share.
Expense _paybackExpense({
  String date = '2026-01-05',
  double amount = 12.5,
  String counterpartyEmail = 'b@test.com',
  String counterpartyName = 'Bob',
  String? recordedByEmail,
  String? recordedByDisplayName,
}) {
  final share = ExpenseEntryShare();
  share.expenseEntryId = 'pe1';
  share.email = counterpartyEmail;
  share.displayName = counterpartyName;
  share.percentage = 100;
  share.fixedAmount = null;
  share.parts = null;
  share.isLocked = false;
  share.createdAt = '';

  final entry = ExpenseEntry(index: 0)
    ..id = 'pe1'
    ..expenseId = 'p1'
    ..amount = amount
    ..quantity = 1
    ..splitMode = 'equal'
    ..createdAt = ''
    ..expenseEntryShares = [share];

  final e = Expense();
  e.id = 'p1';
  e.groupId = 'g1';
  e.name = 'paid_back';
  e.amount = amount;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = date;
  e.createdAt = '';
  e.isPaidBackRow = true;
  e.category = null;
  e.groupMemberShareStatistic = {counterpartyEmail: amount};
  e.expenseEntries = {'pe1': entry};
  e.recordedByEmail = recordedByEmail;
  e.recordedByDisplayName = recordedByDisplayName;
  return e;
}

Future<void> _pump(
  WidgetTester tester,
  Expense expense, {
  Brightness brightness = Brightness.light,
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
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetailRead(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('summary card shows title, total, payer and category', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text(l10n.toCurrency(20)), findsWidgets);
    // Combined design_11 payer line: "{payer} paid" (no current auth user in
    // the test harness, so the payer "Alice" is not "you").
    expect(find.text(l10n.expensePaidByOther('Alice')), findsOneWidget);
    // Category now lives only in the summary subtitle ("{category} · {date}"),
    // not a separate Tags section (F56). Match the category name as a substring.
    expect(
      find.textContaining(ExpenseCategory.food.getDisplayName(l10n)),
      findsOneWidget,
    );
    // Breakdown heading now reflects the split mode (entries default to
    // 'equal'), matching the v3 prototype instead of the generic "Who owes what".
    expect(find.text(l10n.splitEquallyLabel), findsOneWidget);
    expect(find.byType(SoftCard), findsWidgets);
  });

  testWidgets('Edit and Delete actions are present', (tester) async {
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('per-member breakdown renders a row per involved member', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('breakdown is ONE card with non-spaced joined rows (F122)', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    // The screen has exactly two SoftCards: the summary card and the single
    // breakdown card. If the breakdown reverted to one card per member there
    // would be three or more (F122: not one SoftCard per member).
    expect(find.byType(SoftCard), findsNWidgets(2));
  });

  testWidgets(
    'sub-labels map to role: payer "paid €X" / debtor "owes <payer>" (F123)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
          paidBy: 'a@test.com',
        ),
      );

      // Alice paid → "paid €20.00" sub-label (rendered green via success token).
      expect(
        find.text(l10n.expenseMemberPaidAmount(l10n.toCurrency(20))),
        findsOneWidget,
      );
      // Bob owes the payer Alice → "owes Alice".
      expect(find.text(l10n.expenseMemberOwesName('Alice')), findsOneWidget);
      // Old wording is gone.
      expect(find.text('lent'), findsNothing);
      expect(find.text('owes'), findsNothing);
      expect(find.text(l10n.expensePaidBy), findsNothing);
    },
  );

  testWidgets(
    'trailing amount is the plain single-line share, not two-line colored net (F124)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
        ),
      );

      // Each row's trailing amount shows the member's SHARE (€10.00), a single
      // plain figure — one per member. The old treatment rendered a grey
      // "lent"/"owes" label ABOVE a colored net; those labels are asserted gone
      // above. The trailing MoneyText carries no MoneySemantic tint here.
      final tenText = find.text(l10n.toCurrency(10));
      expect(tenText, findsNWidgets(2));
      for (final e in tenText.evaluate()) {
        final color = (e.widget as Text).style?.color;
        final scheme = Theme.of(e).colorScheme;
        // Plain onSurface, never the success/danger semantic colors.
        expect(color, scheme.onSurface);
      }
    },
  );

  testWidgets('Review & claim banner shows for a claim expense', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 3,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 30,
        entrySplitMode: 'claim',
      ),
    );

    expect(find.text(l10n.expenseReviewClaimTitle), findsOneWidget);
  });

  testWidgets('Review & claim banner is absent for a quick expense', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text(l10n.expenseReviewClaimTitle), findsNothing);
  });

  testWidgets(
    'Review & claim banner is absent for an old itemized expense (no claim units)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 3,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 30,
        ),
      );

      expect(find.text(l10n.expenseReviewClaimTitle), findsNothing);
    },
  );

  testWidgets(
    'header card has no divider between the amount and the payer row (F121)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
        ),
      );

      // The v3 handoff header card runs straight from the big amount into the
      // "{payer} paid" row with no hairline between them. Removing the divider is
      // F121; the breakdown card's non-spaced member rows (F122) never used a
      // Divider, so there should be no Divider anywhere in this view.
      expect(find.byType(Divider), findsNothing);
      // Sanity: the amount and payer row both still render.
      expect(find.text(l10n.toCurrency(20)), findsWidgets);
      expect(find.text(l10n.expensePaidByOther('Alice')), findsOneWidget);
    },
  );

  // cosmetic-round-2026-07 (you-owe alignment): the net "you owe / you get
  // back" line is right-aligned — flush to the summary card's content edge — not
  // parked mid-row by a Flexible+Spacer pair that split the free space.
  testWidgets('summary net line is right-aligned to the card content edge', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    // No current auth user in the harness → the net phrase is "not involved";
    // its alignment is what matters here, not the wording.
    final netFinder = find.text(l10n.expenseNoShares);
    expect(netFinder, findsOneWidget);

    // The summary card is the first SoftCard; its content padding is 18.
    final cardRect = tester.getRect(find.byType(SoftCard).first);
    final netRect = tester.getRect(netFinder);
    final payerRect = tester.getRect(
      find.text(l10n.expensePaidByOther('Alice')),
    );

    // Net label hugs the right content edge (card right − 18px padding)...
    expect(netRect.right, moreOrLessEquals(cardRect.right - 18, epsilon: 1.0));
    // ...and sits to the right of the payer line (not overlapping / left of it).
    expect(netRect.left, greaterThan(payerRect.right));
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      _expense(
        entryCount: 3,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 30,
      ),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  // 13 — plain case, no regression
  testWidgets('an unguarded delete shows today plain confirmation', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text(l10n.expenseDeleteItemTitle), findsOneWidget);
    expect(find.text(l10n.expenseDeleteItemMessage), findsOneWidget);
    expect(find.text(l10n.expenseDeleteSettledTitle), findsNothing);
    expect(find.text(l10n.expenseDeletePaybackTitle), findsNothing);
  });

  // 14 — a payback dated strictly before the expense is not a guard trigger
  testWidgets(
    'a payback dated before the expense keeps the plain confirmation',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
        ),
        paybacks: [_paybackExpense(date: '2025-12-31')],
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseDeleteItemMessage), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSettledTitle), findsNothing);
    },
  );

  // 15 — guarded: normal expense already covered by a same-day payback.
  // Cancelling writes nothing.
  testWidgets(
    'a settled expense warns that balances shift, and cancel writes nothing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
        ),
        paybacks: [_paybackExpense(date: '2026-01-01')],
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseDeleteSettledTitle), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSettledMessage(1)), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      // The sheet is gone, the expense screen is still here...
      expect(find.text(l10n.expenseDeleteSettledTitle), findsNothing);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      // ...and NOTHING was written: every ExpenseRepository.delete outcome ends in
      // one of these two snackbars, so their absence is the zero-write proof.
      expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
      expect(find.text(l10n.expenseDeleteError), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // 16 — guarded: the payback row itself. Cancelling writes nothing.
  testWidgets(
    'deleting a payback row names the counterparty and amount, and cancel writes nothing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _paybackExpense(amount: 12.5, counterpartyName: 'Bob'),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseDeletePaybackTitle), findsOneWidget);
      expect(
        find.text(
          l10n.expenseDeletePaybackMessage(l10n.toCurrency(12.5), 'Bob'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseDeletePaybackTitle), findsNothing);
      expect(find.text('paid_back'), findsOneWidget);
      expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
      expect(find.text(l10n.expenseDeleteError), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // 17 — the probe is skipped entirely when the row being deleted IS a
  // settlement: classifyExpenseDeletion never reads the group's other rows in
  // that branch, so fetching them first would be a wasted round-trip.
  testWidgets('deleting a payback row never probes the group', (tester) async {
    var loadCalls = 0;
    await _pump(
      tester,
      _paybackExpense(amount: 12.5, counterpartyName: 'Bob'),
      loader: (_) async {
        loadCalls++;
        return const [];
      },
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(loadCalls, 0);
  });

  // 18 — the bug fix: a slow/hanging probe must not leave the delete action
  // tappable, or a repeat tap would start a second probe and, once both
  // resolve, stack a second confirmation sheet.
  testWidgets(
    'the delete action shows progress and ignores a second tap while the probe is in flight',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      var loadCalls = 0;
      final completer = Completer<List<Expense>>();
      await _pump(
        tester,
        _expense(
          entryCount: 1,
          shareStat: const {'a@test.com': 10, 'b@test.com': 10},
          amount: 20,
        ),
        loader: (_) {
          loadCalls++;
          return completer.future;
        },
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // Probe in flight: the delete icon is replaced by progress, and the
      // confirmation has not appeared yet.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.expenseDeleteItemTitle), findsNothing);
      expect(loadCalls, 1);

      // A second tap on the DELETE action while busy must be a no-op —
      // HeaderIconButton ignores taps while `loading`. Scope the finder by the
      // action's tooltip: the header's first HeaderIconButton is the leading
      // back button, whose tap would be a no-op for unrelated reasons.
      final deleteAction = find.ancestor(
        of: find.byTooltip(l10n.delete),
        matching: find.byType(HeaderIconButton),
      );
      expect(deleteAction, findsOneWidget);
      await tester.tap(deleteAction, warnIfMissed: false);
      await tester.pump();
      expect(loadCalls, 1);

      completer.complete(const []);
      await tester.pumpAndSettle();

      // Exactly one confirmation appears once the single probe resolves.
      expect(find.text(l10n.expenseDeleteItemTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // 32 — criterion: the expense read view shows who recorded a payback.
  testWidgets('the read view names the recorder of an on-behalf payback', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _paybackExpense(
        recordedByEmail: 'b@test.com',
        recordedByDisplayName: 'Bob',
      ),
    );

    expect(find.text(l10n.paybackRecordedBy('Bob')), findsOneWidget);
  });

  // 33
  testWidgets('the read view shows no attribution when the payer recorded it', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _paybackExpense(
        recordedByEmail: 'a@test.com',
        recordedByDisplayName: 'Alice',
      ),
    );

    expect(find.text(l10n.paybackRecordedBy('Alice')), findsNothing);
  });
}
