import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
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

Group _group({List<GroupMember>? members}) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = false;
  g.groupMembers = members ??
      [
        _member('a@test.com', 'Alice'),
        _member('b@test.com', 'Bob'),
      ];
  g.expenses = [];
  return g;
}

/// Builds a claim unit entry (split_mode 'claim', quantity 1) with [claimers].
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
        ..percentage = 100 / claimers.length
        ..fixedAmount = null
        ..parts = null
        ..isLocked = false
        ..createdAt = ''),
  ];
  return e;
}

/// An itemized expense: one unit claimed by Alice (€10), one unit split between
/// Alice + Bob (€6 → €3 each), one unclaimed unit (€4). Total €20, claimed €16.
Expense _itemizedExpense() {
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
    'u1': _unit(0, 'u1', 'Cheese', 10, [const MapEntry('a@test.com', 'Alice')]),
    'u2': _unit(1, 'u2', 'Wine', 6, [
      const MapEntry('a@test.com', 'Alice'),
      const MapEntry('b@test.com', 'Bob'),
    ]),
    'u3': _unit(2, 'u3', 'Bread', 4, const []),
  };
  e.groupMemberShareStatistic = {'a@test.com': 13, 'b@test.com': 3};
  return e;
}

class _FakeClaimNotifier extends ClaimNotifier {
  _FakeClaimNotifier(this._expense);

  final Expense _expense;

  @override
  Future<Expense> build(String groupId, String expenseId) async => _expense;
}

Future<void> _pump(
  WidgetTester tester, {
  required Expense expense,
  Brightness brightness = Brightness.light,
  List<GroupMember>? members,
}) async {
  final group = _group(members: members);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimProvider(group.id, expense.id)
            .overrideWith(() => _FakeClaimNotifier(expense)),
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
            // Disable the presence-pulse loop so pumpAndSettle can settle; this
            // also exercises the reduced-motion (static dot) code path.
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

  testWidgets('header shows merchant and live-presence label', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // Merchant name appears in the DeunHeader title (may also appear elsewhere).
    expect(find.text('Supermarket'), findsWidgets);
    // Presence live text in the DeunHeader subtitle.
    expect(find.text(l10n.claimPresenceLive), findsOneWidget);
    // No AppBar — the claim page uses DeunHeader exclusively.
    expect(find.byType(AppBar), findsNothing);
    // DeunHeader is rendered.
    expect(find.byType(DeunHeader), findsOneWidget);
  });

  testWidgets('header has a single edit affordance (no duplicate)', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // Exactly one widget with the edit tooltip — duplicate from body is gone.
    expect(
      find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == l10n.claimEditItems,
      ),
      findsOneWidget,
    );
    // The edit icon appears exactly once (the trailing IconButton in DeunHeader).
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('header edit icon is present and wired up', (tester) async {
    // Verify the edit icon is in the DeunHeader (trailing slot).
    // We do NOT tap it here because GoRouter is not available in the test
    // MaterialApp — the notifier/edit route requires a GoRouter context.
    await _pump(tester, expense: _itemizedExpense());
    // The edit icon lives in the DeunHeader trailing slot.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    // Confirm it is a descendant of the DeunHeader (not a body button).
    expect(
      find.descendant(
        of: find.byType(DeunHeader),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('summary card shows your share, progress, unclaimed and per-member',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // No signed-in user in tests → persona defaults to ''; "your share" is 0.
    expect(find.text(l10n.claimYourShare), findsOneWidget);
    // Progress caption: "€16.00 of €20.00 claimed".
    expect(
      find.text(l10n.claimProgressLabel(l10n.toCurrency(16), l10n.toCurrency(20))),
      findsOneWidget,
    );
    // Unclaimed remainder €4 is surfaced.
    expect(find.textContaining(l10n.toCurrency(4)), findsWidgets);
    // Per-member section + both claimers' totals.
    expect(find.text(l10n.claimPerMemberLabel), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsWidgets);
    // Alice total = 10 + 3 = 13; Bob = 3.
    expect(find.text(l10n.toCurrency(13)), findsWidgets);
  });

  testWidgets('persona switcher renders one avatar with name per member',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // The "Preview as" label sits on the switcher card.
    expect(find.text(l10n.claimPreviewAs), findsOneWidget);
    // One avatar+name persona per group member.
    for (final email in ['a@test.com', 'b@test.com']) {
      final persona = find.byKey(ValueKey('persona:$email'));
      expect(persona, findsOneWidget);
      expect(
        find.descendant(of: persona, matching: find.byType(MemberAvatar)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('persona:a@test.com')),
        matching: find.text('Alice'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('persona:b@test.com')),
        matching: find.text('Bob'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('persona switcher changes the displayed your-share',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // Preview as Alice → your share becomes €13.
    await tester.tap(find.byKey(const ValueKey('persona:a@test.com')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.toCurrency(13)), findsWidgets);

    // Preview as Bob → your share becomes €3.
    await tester.tap(find.byKey(const ValueKey('persona:b@test.com')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.toCurrency(3)), findsWidgets);
  });

  testWidgets('selected persona avatar shows the ink selection ring',
      (tester) async {
    await _pump(tester, expense: _itemizedExpense());

    MemberAvatar avatarFor(String email) => tester.widget<MemberAvatar>(
          find.descendant(
            of: find.byKey(ValueKey('persona:$email')),
            matching: find.byType(MemberAvatar),
          ),
        );
    SemanticColors semanticOf(String email) => Theme.of(
          tester.element(find.byKey(ValueKey('persona:$email'))),
        ).extension<SemanticColors>()!;

    // Select Alice → her avatar carries the ink ring, Bob's stays transparent.
    await tester.tap(find.byKey(const ValueKey('persona:a@test.com')));
    await tester.pumpAndSettle();
    expect(avatarFor('a@test.com').ringWidth, greaterThan(0));
    expect(
      avatarFor('a@test.com').ringColor,
      semanticOf('a@test.com').ink,
    );
    expect(avatarFor('b@test.com').ringColor, Colors.transparent);

    // Select Bob → the ring moves to him.
    await tester.tap(find.byKey(const ValueKey('persona:b@test.com')));
    await tester.pumpAndSettle();
    expect(avatarFor('b@test.com').ringColor, semanticOf('b@test.com').ink);
    expect(avatarFor('a@test.com').ringColor, Colors.transparent);
  });

  testWidgets('persona switcher with 7 long-named members does not overflow',
      (tester) async {
    final members = [
      for (var i = 0; i < 7; i++)
        _member(
          'member$i@test.com',
          'Maximiliana Bartholomea von Hohenlohe-Langenburg $i',
        ),
    ];
    await _pump(tester, expense: _itemizedExpense(), members: members);

    // All 7 personas render inside the horizontally scrollable strip …
    for (var i = 0; i < 7; i++) {
      expect(
        find.byKey(ValueKey('persona:member$i@test.com'), skipOffstage: false),
        findsOneWidget,
      );
    }
    // … without any layout overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('item list renders a row per claim unit', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // The item area is below the fold of the lazily-built list — scroll it in.
    // The per-member strip adds its own horizontal Scrollable, so target the
    // outer vertical ListView explicitly.
    await tester.scrollUntilVisible(
      find.text('Bread'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.claimItemsCaption.toUpperCase()), findsOneWidget);
    expect(find.text('Cheese'), findsOneWidget);
    expect(find.text('Wine'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    // The unclaimed unit (Bread) shows the dashed "take one" chip (E3-T3).
    expect(find.text(l10n.claimTakeOne), findsWidgets);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      expense: _itemizedExpense(),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
