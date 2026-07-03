import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail_list.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _myEmail = 'me@test.com';

GroupMember _member(String email) {
  final m = GroupMember();
  m.groupId = 'g';
  m.email = email;
  m.displayName = email.split('@').first;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Group _group() {
  final g = Group();
  g.id = 'g';
  g.name = 'Trip';
  g.colorValue = kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = false;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [_member(_myEmail), _member('sam@test.com')];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

ExpenseEntryShare _share(String email, double percentage) {
  final s = ExpenseEntryShare();
  s.expenseEntryId = 'ee';
  s.email = email;
  s.displayName = email.split('@').first;
  s.percentage = percentage;
  s.fixedAmount = null;
  s.parts = null;
  s.isLocked = false;
  s.createdAt = '';
  return s;
}

ExpenseEntry _entry(int index, double amount, List<ExpenseEntryShare> shares) {
  final e = ExpenseEntry(index: index);
  e.id = 'entry$index';
  e.expenseId = 'x';
  e.name = 'item$index';
  e.amount = amount;
  e.quantity = 1;
  e.splitMode = 'equal';
  e.createdAt = '';
  e.expenseEntryShares = shares;
  return e;
}

Expense _quick({required String id, required String date}) {
  final e = Expense();
  e.id = id;
  e.groupId = 'g';
  e.name = 'Quick $id';
  e.amount = 20;
  e.paidBy = 'sam@test.com';
  e.expenseDate = date;
  e.createdAt = date;
  e.isPaidBackRow = false;
  e.category = null;
  e.paidByDisplayName = 'sam';
  e.expenseEntries = {'e0': _entry(0, 20, [_share(_myEmail, 50), _share('sam@test.com', 50)])};
  e.groupMemberShareStatistic = {_myEmail: 10, 'sam@test.com': 10};
  return e;
}

Expense _itemized({required String id, required String date}) {
  final e = Expense();
  e.id = id;
  e.groupId = 'g';
  e.name = 'Itemized $id';
  e.amount = 30;
  e.paidBy = 'sam@test.com';
  e.expenseDate = date;
  e.createdAt = date;
  e.isPaidBackRow = false;
  e.category = null;
  e.paidByDisplayName = 'sam';
  e.expenseEntries = {
    'e0': _entry(0, 20, [_share('sam@test.com', 100)]),
    'e1': _entry(1, 10, [_share('sam@test.com', 100)]),
  };
  // Only sam has claimed → €10 unclaimed for the €30 total.
  e.groupMemberShareStatistic = {'sam@test.com': 20};
  return e;
}

Expense _payback({required String id, required String date}) {
  final e = Expense();
  e.id = id;
  e.groupId = 'g';
  e.name = 'Payback $id';
  e.amount = 40;
  e.paidBy = 'sam@test.com';
  e.expenseDate = date;
  e.createdAt = date;
  e.isPaidBackRow = true;
  e.category = null;
  e.paidByDisplayName = 'sam';
  e.expenseEntries = {'e0': _entry(0, 40, [_share(_myEmail, 100)])};
  e.groupMemberShareStatistic = {};
  return e;
}

class _FakeExpenseListNotifier extends ExpenseListNotifier {
  _FakeExpenseListNotifier(this._expenses);

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> build(String groupId) async => _expenses;

  @override
  Future<void> reload(String groupId) async {}

  @override
  Future<void> loadMoreEntries(String groupId) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Expense> expenses,
  Brightness brightness = Brightness.light,
}) async {
  final group = _group();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseListProvider(group.id).overrideWith(() => _FakeExpenseListNotifier(expenses)),
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
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, brightness).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: GroupDetailList(group: group)),
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
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
    await Supabase.initialize(url: 'http://localhost:54321', anonKey: 'test-anon-key');
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('renders a day header for the ledger', (tester) async {
    await _pump(tester, expenses: [_quick(id: '1', date: '2026-01-02T10:00:00')]);
    // The day header uses formatDate; an older date renders as "d MMM".
    expect(find.text('2 Jan'), findsOneWidget);
  });

  testWidgets('quick row shows title and amount', (tester) async {
    await _pump(tester, expenses: [_quick(id: '1', date: '2026-01-02T10:00:00')]);
    expect(find.text('Quick 1'), findsOneWidget);
  });

  testWidgets('itemized row shows a Tap-to-claim icon button and unclaimed meta', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expenses: [_itemized(id: '2', date: '2026-01-02T10:00:00')]);

    // The claim affordance is an icon button (tooltip carries the label), not
    // a text pill.
    final claimButton = find.byWidgetPredicate(
      (w) => w is HeaderIconButton && w.tooltip == l10n.groupDetailTapToClaim,
    );
    expect(claimButton, findsOneWidget);
    expect(find.text(l10n.groupDetailTapToClaim), findsNothing);

    // €10 of the €30 total is still unclaimed.
    expect(find.text(l10n.groupDetailUnclaimed(10)), findsOneWidget);
  });

  testWidgets('itemized row shows the itemized indicator and payer subline', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expenses: [_itemized(id: '2', date: '2026-01-02T10:00:00')]);

    // Subline is "sam paid · itemized" (paidBy is sam, not the current user).
    expect(find.textContaining(l10n.groupDetailItemizedTag), findsOneWidget);
    expect(find.textContaining(l10n.expensePaidByOther('sam')), findsOneWidget);
  });

  testWidgets('itemized row stacks claimer avatars with AvatarStack', (tester) async {
    await _pump(tester, expenses: [_itemized(id: '2', date: '2026-01-02T10:00:00')]);
    // Claimers (sam) render via the overlapping AvatarStack, not a spaced Row.
    expect(find.byType(AvatarStack), findsOneWidget);
  });

  testWidgets('unclaimed meta and claim button sit on opposite sides', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expenses: [_itemized(id: '2', date: '2026-01-02T10:00:00')]);

    final metaLeft = tester.getTopLeft(find.text(l10n.groupDetailUnclaimed(10))).dx;
    final buttonLeft = tester
        .getTopLeft(find.byWidgetPredicate(
          (w) => w is HeaderIconButton && w.tooltip == l10n.groupDetailTapToClaim,
        ))
        .dx;
    // Unclaimed meta on the LEFT, claim button on the RIGHT (handoff layout).
    expect(metaLeft, lessThan(buttonLeft));
  });

  testWidgets('payback row shows the PAYMENT tag', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expenses: [_payback(id: '3', date: '2026-01-02T10:00:00')]);
    expect(find.text(l10n.groupDetailPaymentTag), findsOneWidget);
  });

  testWidgets('tapping a quick row navigates to the read expense detail', (tester) async {
    final group = _group();
    String? visited;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: GroupDetailList(group: group)),
          ),
        ),
        // Quick expenses open the read detail (Screen 11), not the editor.
        GoRoute(
          path: '/group/details/expense-detail',
          builder: (context, state) {
            visited = '/group/details/expense-detail';
            return const Scaffold(body: Text('detail'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider(group.id)
              .overrideWith(() => _FakeExpenseListNotifier([_quick(id: '1', date: '2026-01-02T10:00:00')])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick 1'));
    await tester.pumpAndSettle();

    expect(visited, '/group/details/expense-detail');
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('builds all three row types in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      brightness: Brightness.dark,
      expenses: [
        _quick(id: '1', date: '2026-01-02T10:00:00'),
        _itemized(id: '2', date: '2026-01-02T09:00:00'),
        _payback(id: '3', date: '2026-01-01T10:00:00'),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Quick 1'), findsOneWidget);
    expect(find.text('Itemized 2'), findsOneWidget);
  });

  testWidgets('rows within a date group share one card; date groups are separated', (tester) async {
    await _pump(
      tester,
      expenses: [
        // Two expenses on the same day → one joined card.
        _quick(id: '1', date: '2026-01-02T10:00:00'),
        _itemized(id: '2', date: '2026-01-02T09:00:00'),
        // A third on a different day → its own card.
        _quick(id: '3', date: '2026-01-01T10:00:00'),
      ],
    );

    // Two date groups → exactly two SoftCards (not one per expense row).
    expect(find.byType(SoftCard), findsNWidgets(2));
    // Both same-day rows are present inside the first card.
    expect(find.text('Quick 1'), findsOneWidget);
    expect(find.text('Itemized 2'), findsOneWidget);
    expect(find.text('Quick 3'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no expenses', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expenses: []);
    expect(find.text(l10n.groupExpenseNoEntries), findsOneWidget);
  });
}
