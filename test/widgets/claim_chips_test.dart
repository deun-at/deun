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
  List<MapEntry<String, String>> claimers,
) {
  final e = ExpenseEntry(index: index);
  e.id = id;
  e.expenseId = 'e1';
  e.name = name;
  e.amount = amount;
  e.quantity = 1;
  e.splitMode = 'claim';
  e.createdAt = '';
  e.itemGroupId = null;
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
  // Tall surface so the whole claim screen (summary + items + confirm bar) is
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

  testWidgets('tapping a "take one" chip claims the unit for the persona',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    await _pickPersona(tester, 'a@test.com');

    expect(_fake.claimCalls, isEmpty);
    await tester.tap(find.text(l10n.claimTakeOne).first);
    await tester.pumpAndSettle();

    // First open unit is u1 (Cheese); persona is Alice.
    expect(_fake.claimCalls.length, 1);
    expect(_fake.claimCalls.first.$1, 'u1');
    expect(_fake.claimCalls.first.$2, 'a@test.com');
  });

  testWidgets('tapping a chip claimed by you unclaims it', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    await _pickPersona(tester, 'a@test.com');

    // Claim the first open unit, then tap its (now claimed-by-you) chip.
    await tester.tap(find.text(l10n.claimTakeOne).first);
    await tester.pumpAndSettle();
    // u2 (Wine) is split between Alice+Bob → its chip is claimed-by-you.
    // Tap the avatar pill for u1 (Cheese), now claimed solely by Alice.
    await tester.tap(find.byType(AvatarStack).first);
    await tester.pumpAndSettle();

    expect(_fake.unclaimCalls, isNotEmpty);
    expect(_fake.unclaimCalls.last.$2, 'a@test.com');
  });

  testWidgets('Split one picker calls splitUnit with chosen members',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());

    // Open the split picker on the first open unit (the "Split one" button is
    // an icon button with a tooltip).
    await tester.tap(find.byTooltip(l10n.claimSplitOne).first);
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

  testWidgets('unclaimed callout shows when units remain unclaimed',
      (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());
    // u1 (€10) + u3 (€4) unclaimed = €14.
    expect(find.text(l10n.claimUnclaimedCallout(l10n.toCurrency(14))),
        findsOneWidget);
    expect(find.text(l10n.claimNudge), findsOneWidget);
  });

  testWidgets('no unclaimed callout when fully claimed', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _fullyClaimed());
    expect(find.textContaining('unclaimed'), findsNothing);
    expect(find.text(l10n.claimNudge), findsNothing);
  });

  testWidgets('Confirm opens the success sheet', (tester) async {
    final l10n = await _l10n();
    await _pump(tester, expense: _expense());

    final confirm = find.textContaining('Confirm');
    expect(confirm, findsOneWidget);
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text(l10n.claimConfirmedTitle), findsOneWidget);
    expect(find.text(l10n.claimConfirmedDone), findsOneWidget);
  });

  testWidgets('chips render in dark mode without throwing', (tester) async {
    await _pump(tester, expense: _expense(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
