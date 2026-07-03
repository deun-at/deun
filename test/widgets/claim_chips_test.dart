import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
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
  g.simplifiedExpenses = false;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

ExpenseEntry _unit(
  int index,
  String id,
  String name,
  double amount,
  List<MapEntry<String, String>> claimers, {
  String? itemGroupId,
}) {
  final e = ExpenseEntry(index: index);
  e.id = id;
  e.expenseId = 'e1';
  e.name = name;
  e.amount = amount;
  e.quantity = 1;
  e.splitMode = 'claim';
  e.createdAt = '';
  e.itemGroupId = itemGroupId;
  e.expenseEntryShares = [
    for (final c in claimers)
      (ExpenseEntryShare()
        ..expenseEntryId = id
        ..email = c.key
        ..displayName = c.value
        ..percentage = claimers.isEmpty ? 0 : 100 / claimers.length
        ..fixedAmount = null
        ..parts = null
        ..isLocked = false
        ..createdAt = ''),
  ];
  return e;
}

Expense _expense() {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Supermarket';
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.amount = 20;
  e.expenseEntries = {
    'u1': _unit(0, 'u1', 'Cheese', 10, const []),
    'u2': _unit(1, 'u2', 'Wine', 6, [
      const MapEntry('a@test.com', 'Alice'),
      const MapEntry('b@test.com', 'Bob'),
    ]),
    'u3': _unit(2, 'u3', 'Bread', 4, const []),
  };
  e.groupMemberShareStatistic = {};
  return e;
}

Expense _fullyClaimed() {
  final e = _expense();
  e.expenseEntries = {
    'u1': _unit(0, 'u1', 'Cheese', 10, [const MapEntry('b@test.com', 'Bob')]),
    'u2': _unit(1, 'u2', 'Wine', 6, [const MapEntry('b@test.com', 'Bob')]),
  };
  return e;
}

/// One qty-3 item (Cola, €2 each, item_group_id 'ig-cola'): unit c1 claimed
/// solo by Alice, unit c2 split Alice+Bob (€1 each), unit c3 free.
Expense _grouped() {
  final e = _expense();
  e.amount = 6;
  e.expenseEntries = {
    'c1': _unit(0, 'c1', 'Cola', 2, [const MapEntry('a@test.com', 'Alice')],
        itemGroupId: 'ig-cola'),
    'c2': _unit(
        1,
        'c2',
        'Cola',
        2,
        [
          const MapEntry('a@test.com', 'Alice'),
          const MapEntry('b@test.com', 'Bob'),
        ],
        itemGroupId: 'ig-cola'),
    'c3': _unit(2, 'c3', 'Cola', 2, const [], itemGroupId: 'ig-cola'),
  };
  return e;
}

/// Records claim mutations and mutates local state so chips re-render, without
/// touching Supabase.
class _FakeClaimNotifier extends ClaimNotifier {
  _FakeClaimNotifier(this._expense);

  final Expense _expense;

  final List<(String, String)> claimCalls = [];
  final List<(String, String)> unclaimCalls = [];
  final List<(String, List<String>)> splitCalls = [];

  @override
  Future<Expense> build(String groupId, String expenseId) async => _expense;

  void _setShares(String entryId, List<String> emails) {
    final entry = state.value!.expenseEntries[entryId]!;
    entry.expenseEntryShares = [
      for (final email in emails)
        (ExpenseEntryShare()
          ..expenseEntryId = entryId
          ..email = email
          ..displayName = email == 'a@test.com' ? 'Alice' : 'Bob'
          ..percentage = 100 / emails.length
          ..fixedAmount = null
          ..parts = null
          ..isLocked = false
          ..createdAt = ''),
    ];
    state = AsyncData(state.value!);
    ref.notifyListeners();
  }

  @override
  Future<void> claimUnit(String unitEntryId, String email) async {
    claimCalls.add((unitEntryId, email));
    final current = state.value!.expenseEntries[unitEntryId]!.expenseEntryShares
        .map((s) => s.email)
        .toList();
    if (!current.contains(email)) _setShares(unitEntryId, [...current, email]);
  }

  @override
  Future<void> unclaimUnit(String unitEntryId, String email) async {
    unclaimCalls.add((unitEntryId, email));
    final current = state.value!.expenseEntries[unitEntryId]!.expenseEntryShares
        .map((s) => s.email)
        .toList();
    _setShares(unitEntryId, current.where((e) => e != email).toList());
  }

  @override
  Future<void> splitUnit(String unitEntryId, List<String> claimerEmails) async {
    splitCalls.add((unitEntryId, claimerEmails));
    _setShares(unitEntryId, claimerEmails);
  }
}

late _FakeClaimNotifier _fake;

Future<void> _pump(
  WidgetTester tester, {
  required Expense expense,
  Brightness brightness = Brightness.light,
}) async {
  _fake = _FakeClaimNotifier(expense);
  // Tall surface so the whole claim screen (summary + items + hint bar) is
  // laid out at once — the body is a lazily-built ListView.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final group = _group();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimProvider(group.id, expense.id).overrideWith(() => _fake),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Theme(
              data: getThemeData(context, kBrandSeed, brightness)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: ClaimPage(group: group, expense: expense),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// Selects the persona with [email] in the avatar switcher so claim mutations
/// target a real email (tests have no signed-in user, so the default persona
/// is empty).
Future<void> _pickPersona(WidgetTester tester, String email) async {
  await tester.tap(find.byKey(ValueKey('persona:$email')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
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

  testWidgets('open unit shows a "take one" chip', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    expect(find.text(l10n.claimTakeOne), findsWidgets);
  });

  testWidgets('tapping a free slot claims the unit solo via the RPC path',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    await _pickPersona(tester, 'a@test.com');

    expect(_fake.claimCalls, isEmpty);
    await tester.tap(find.text(l10n.claimTakeOne).first);
    await tester.pumpAndSettle();

    // First open unit is u1 (Cheese); persona is Alice → claimUnit (solo).
    expect(_fake.claimCalls.length, 1);
    expect(_fake.claimCalls.first.$1, 'u1');
    expect(_fake.claimCalls.first.$2, 'a@test.com');
    expect(_fake.splitCalls, isEmpty);
  });

  testWidgets(
      'grouped item card shows ×N, "each · ordered" subline, and one chip '
      'per unit (solo / split / free)', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _grouped());

    // One card: name + ×3 in the title, "€2.00 each · 3 ordered" subline.
    expect(find.textContaining('Cola'), findsOneWidget);
    expect(find.textContaining('×3'), findsOneWidget);
    expect(
      find.text(l10n.claimEachOrdered(l10n.toCurrency(2), 3)),
      findsOneWidget,
    );

    // Solo slot → claimer name chip.
    final solo = find.byKey(const ValueKey('slot:c1'));
    expect(solo, findsOneWidget);
    expect(find.descendant(of: solo, matching: find.text('Alice')),
        findsOneWidget);

    // Split slot → stacked avatars + "split · €1.00".
    final split = find.byKey(const ValueKey('slot:c2'));
    expect(split, findsOneWidget);
    expect(
      find.descendant(
        of: split,
        matching: find.text(l10n.claimSplitLabel(l10n.toCurrency(1))),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: split, matching: find.byType(AvatarStack)),
        findsOneWidget);

    // Free slot → dashed "take one".
    final free = find.byKey(const ValueKey('slot:c3'));
    expect(free, findsOneWidget);
    expect(find.descendant(of: free, matching: find.text(l10n.claimTakeOne)),
        findsOneWidget);
  });

  testWidgets('single-unit item card shows the plain unit price subline',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    // Wine (€6, split Alice+Bob) is a single-slot card: no ×N, plain price,
    // one split chip with the €3 per-person cost.
    expect(find.textContaining('×'), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('slot:u2')),
        matching: find.text(l10n.claimSplitLabel(l10n.toCurrency(3))),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a claimed chip opens the modal; unchecking yourself '
      'unclaims via splitUnit', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _grouped());
    await _pickPersona(tester, 'a@test.com');

    // Tap Alice's solo slot → the solo/split modal opens (no mutation yet).
    await tester.tap(find.byKey(const ValueKey('slot:c1')));
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsOneWidget);
    expect(_fake.splitCalls, isEmpty);

    // Uncheck Alice (the sheet's member row) and apply → unit is unclaimed.
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.claimSplitApply));
    await tester.pumpAndSettle();

    expect(_fake.splitCalls.length, 1);
    expect(_fake.splitCalls.first.$1, 'c1');
    expect(_fake.splitCalls.first.$2, isEmpty);
  });

  testWidgets('"Split one" opens the modal on the first free unit and applies '
      'the chosen members', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());

    await tester.tap(find.text(l10n.claimSplitOne).first);
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsOneWidget);

    // Pick Alice and Bob, then apply.
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.claimSplitApply));
    await tester.pumpAndSettle();

    expect(_fake.splitCalls.length, 1);
    expect(_fake.splitCalls.first.$1, 'u1');
    expect(_fake.splitCalls.first.$2.toSet(),
        {'a@test.com', 'b@test.com'});
  });

  testWidgets('"Split one" preselects the persona in the modal',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _grouped());
    await _pickPersona(tester, 'b@test.com');

    // First (only) free unit on the Cola card is c3.
    await tester.tap(find.text(l10n.claimSplitOne).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.claimSplitApply));
    await tester.pumpAndSettle();

    expect(_fake.splitCalls.length, 1);
    expect(_fake.splitCalls.first.$1, 'c3');
    expect(_fake.splitCalls.first.$2, ['b@test.com']);
  });

  testWidgets('"Split one" is dimmed and inert when nothing is free',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _fullyClaimed());

    await tester.tap(find.text(l10n.claimSplitOne).first);
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsNothing);
    expect(_fake.splitCalls, isEmpty);
  });

  testWidgets('"Tap a slot to take one" hint shows only while the persona '
      'holds nothing and free slots remain', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _grouped());
    // No persona claims yet (default persona is '') → hint on the Cola card.
    expect(find.text(l10n.claimTapSlotHint), findsOneWidget);

    // Alice already holds unit c1 → previewing as her hides the hint.
    await _pickPersona(tester, 'a@test.com');
    expect(find.text(l10n.claimTapSlotHint), findsNothing);
  });

  testWidgets('unclaimed callout shows when units remain unclaimed',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    // u1 (€10) + u3 (€4) unclaimed = €14; payer = Alice (F130 copy).
    expect(find.text(l10n.claimUnclaimedCallout(l10n.toCurrency(14), 'Alice')),
        findsOneWidget);
    expect(find.text(l10n.claimNudge), findsOneWidget);
  });

  testWidgets('no unclaimed callout when fully claimed', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _fullyClaimed());
    expect(find.textContaining('unclaimed'), findsNothing);
    expect(find.text(l10n.claimNudge), findsNothing);
  });

  testWidgets(
      'bottom bar is the non-actionable "Tap the items you had" hint '
      '(F132: no explicit confirm step)', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());

    // The hint is present...
    expect(find.text(l10n.claimTapItemsHint), findsOneWidget);
    // ...and there is no actionable confirm button in a button role.
    expect(find.widgetWithText(ElevatedButton, l10n.claimTapItemsHint),
        findsNothing);

    // Tapping a slot commits per tap without any separate confirm press.
    await _pickPersona(tester, 'a@test.com');
    expect(_fake.claimCalls, isEmpty);
    await tester.tap(find.text(l10n.claimTakeOne).first);
    await tester.pumpAndSettle();
    expect(_fake.claimCalls.length, 1);
  });

  testWidgets('chips render in dark mode without throwing', (tester) async {
    await _pump(tester, expense: _expense(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
