import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
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
  _FakeClaimNotifier(this._expense, {int presenceCount = 0})
      : _presenceCount = presenceCount;

  final Expense _expense;
  final int _presenceCount;

  @override
  Future<Expense> build(String groupId, String expenseId) async {
    // Stand in for a live presence sync: the header's live-count reads
    // [claimingNow], which the real notifier fills from the channel's
    // presenceState() — here we inject it directly.
    claimingNow = _presenceCount;
    return _expense;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Expense expense,
  Brightness brightness = Brightness.light,
  List<GroupMember>? members,
  int presenceCount = 0,
}) async {
  final group = _group(members: members);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimProvider(group.id, expense.id).overrideWith(
            () => _FakeClaimNotifier(expense, presenceCount: presenceCount)),
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

  testWidgets('header shows merchant and live claiming count', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // F164: the live count is Realtime *presence* — who is on the screen now —
    // NOT how many members have claimed something. Inject 2 present clients.
    await _pump(tester, expense: _itemizedExpense(), presenceCount: 2);

    // Merchant name appears in the DeunHeader title (may also appear elsewhere).
    expect(find.text('Supermarket'), findsWidgets);
    // F127/F164: presence subtitle reflects the injected presence count (2),
    // not a static "Live" label and not the member-totals count.
    expect(find.text(l10n.claimPresenceCount(2)), findsOneWidget);
    expect(l10n.claimPresenceCount(2), '2 people claiming now');
    // No AppBar — the claim page uses DeunHeader exclusively.
    expect(find.byType(AppBar), findsNothing);
    // DeunHeader is rendered.
    expect(find.byType(DeunHeader), findsOneWidget);
  });

  testWidgets(
      'F164: live count derives from presence, not member-totals length',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // The expense has 2 distinct claimers (Alice + Bob) in memberTotals, but
    // only 1 client is actually present. The header must show the presence
    // count (1), proving it is NOT fed summary.memberTotals.length.
    await _pump(tester, expense: _itemizedExpense(), presenceCount: 1);

    expect(find.text(l10n.claimPresenceCount(1)), findsOneWidget);
    expect(l10n.claimPresenceCount(1), '1 person claiming now');
    // The 2-member (memberTotals.length) string must NOT appear as the subtitle.
    expect(find.text(l10n.claimPresenceCount(2)), findsNothing);
  });

  testWidgets('F164: zero presence shows the "No one claiming yet" branch',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // No clients tracked → presence count 0 → the =0 plural branch.
    await _pump(tester, expense: _itemizedExpense(), presenceCount: 0);

    expect(find.text(l10n.claimPresenceCount(0)), findsOneWidget);
    expect(l10n.claimPresenceCount(0), 'No one claiming yet');
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

  testWidgets('summary card shows your share, progress, left and per-person',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // F128: label reads "You, your share".
    expect(l10n.claimYourShare, 'You, your share');
    expect(find.text(l10n.claimYourShare), findsOneWidget);
    // F128: right-side header — no signed-in user → persona '' claimed nothing.
    expect(find.text(l10n.claimYouClaimedItems(0)), findsOneWidget);
    // Progress caption: "€16.00 of €20.00 claimed".
    expect(
      find.text(l10n.claimProgressLabel(l10n.toCurrency(16), l10n.toCurrency(20))),
      findsOneWidget,
    );
    // F128: the €4 remainder is surfaced as "€4.00 left" (amber).
    expect(find.text(l10n.claimLeftLabel(l10n.toCurrency(4))), findsOneWidget);
    // F129: per-person totals still surface each claimer's amount as a chip.
    // Alice total = 10 + 3 = 13; Bob = 3.
    expect(find.text(l10n.toCurrency(13)), findsWidgets);
    expect(find.text(l10n.toCurrency(3)), findsWidgets);
  });

  testWidgets('F129: per-person strip is compact avatar+amount, no label/names',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // The "Per person" section label is gone.
    expect(find.text(l10n.claimPerMemberLabel), findsNothing);

    // The chip strip lives on the dark hero SummaryCard. Its chips carry an
    // avatar + amount only — the claimer name does not appear inside the chip.
    // Alice's total (€13) chip must not sit alongside her name in the same chip:
    // MoneyText for €13 exists (chip amount), and there is no in-chip name Text.
    expect(find.text(l10n.toCurrency(13)), findsWidgets);
    // Each per-person chip renders a MemberAvatar (avatar-only, no name Text).
    expect(find.byType(MemberAvatar), findsWidgets);
  });

  testWidgets('F128: summary progress bar uses the green success fill',
      (tester) async {
    await _pump(tester, expense: _itemizedExpense());

    final context = tester.element(find.byType(ClaimPage));
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    // The summary card's progress bar (the first ProgressBar on the screen).
    final bar = tester.widget<ProgressBar>(find.byType(ProgressBar).first);
    expect(bar.fillColor, semantic.success);
  });

  testWidgets('F128: the "left" figure is rendered in the amber warning tone',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    final context = tester.element(find.byType(ClaimPage));
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    final left = tester.widget<Text>(
      find.text(l10n.claimLeftLabel(l10n.toCurrency(4))),
    );
    expect(left.style?.color, semantic.warning);
  });

  testWidgets('F130: unclaimed callout shows payer copy + black Nudge pill',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    final context = tester.element(find.byType(ClaimPage));
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    // Explanatory copy: "€4.00 still unclaimed. Alice paid, so they cover the
    // rest unless the group claims it." (payer = Alice).
    expect(
      find.text(l10n.claimUnclaimedCallout(l10n.toCurrency(4), 'Alice')),
      findsOneWidget,
    );

    // The Nudge action is a solid black (ink) pill, not a plain text link.
    final nudge = find.ancestor(
      of: find.text(l10n.claimNudge),
      matching: find.byType(Material),
    );
    expect(nudge, findsWidgets);
    final pill = tester.widget<Material>(nudge.first);
    expect(pill.color, semantic.ink);
    // Tapping the pill fires the nudge (snackbar confirmation).
    await tester.tap(find.text(l10n.claimNudge));
    await tester.pump();
    expect(find.text(l10n.claimNudgeSent), findsOneWidget);
  });

  testWidgets('F128: claimed-items count follows the selected persona',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // Preview as Alice → she claims 2 units (Cheese + Wine).
    await tester.tap(find.byKey(const ValueKey('persona:a@test.com')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.claimYouClaimedItems(2)), findsOneWidget);

    // Preview as Bob → he claims 1 unit (Wine).
    await tester.tap(find.byKey(const ValueKey('persona:b@test.com')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.claimYouClaimedItems(1)), findsOneWidget);
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

  testWidgets('item list renders one card per item with its slot chips',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    // The item area is below the fold of the lazily-built list — scroll it in.
    // The per-member strip adds its own horizontal Scrollable, so target the
    // outer vertical ListView explicitly.
    final scrollable = find.byType(Scrollable).first;

    // The eyebrow caption sits directly above the item cards. It shares the
    // vertical viewport with them but scrolls off the top once the last card
    // (Bread) is dragged into view, so assert it at its own scroll position
    // before scrolling further down — a scrolled-past row is disposed by the
    // lazy ListView and would no longer be findable.
    await tester.scrollUntilVisible(
      find.text(l10n.claimItemsCaption.toUpperCase()),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.claimItemsCaption.toUpperCase()), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Bread'), 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Cheese'), findsOneWidget);
    expect(find.text('Wine'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    // The unclaimed unit (Bread) shows the dashed "take one" chip (E3-T3).
    expect(find.text(l10n.claimTakeOne), findsWidgets);
  });

  testWidgets(
      'F163: tapping a claimed chip opens the inline editor, not a modal sheet',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Cheese'), 200,
        scrollable: scrollable);
    await tester.pumpAndSettle();

    // The Cheese unit (u1) is claimed by Alice — tap its chip.
    await tester.tap(find.byKey(const ValueKey('slot:u1')));
    await tester.pumpAndSettle();

    // The inline editor for u1 is now in the tree …
    expect(find.byKey(const ValueKey('editor:u1')), findsOneWidget);
    // … carrying the editor hint copy, and no modal bottom sheet was pushed.
    expect(find.text(l10n.claimSplitEditorHint), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    // Tapping the same chip again collapses the editor (toggle).
    await tester.tap(find.byKey(const ValueKey('slot:u1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor:u1')), findsNothing);
  });

  testWidgets('F163: "Split one" opens the inline editor on a free unit',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, expense: _itemizedExpense());

    final scrollable = find.byType(Scrollable).first;
    // Bread (u3) is the unclaimed unit; scroll its card into view.
    await tester.scrollUntilVisible(find.text('Bread'), 200,
        scrollable: scrollable);
    await tester.pumpAndSettle();

    // Its "Split one" button opens the editor on the first free unit (u3).
    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('Bread'),
        matching: find.byType(SoftCard),
      ),
      matching: find.text(l10n.claimSplitOne),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor:u3')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('F163: an item the persona holds gets the taken-highlight tint',
      (tester) async {
    await _pump(tester, expense: _itemizedExpense());

    // Preview as Alice, who holds Cheese (u1) and half of Wine (u2).
    await tester.tap(find.byKey(const ValueKey('persona:a@test.com')));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Cheese'), 200,
        scrollable: scrollable);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ClaimPage));
    final primary = Theme.of(context).colorScheme.primary;

    // The Cheese card (Alice holds it) carries the primary-tinted fill + border.
    final cheeseCard = tester.widget<SoftCard>(find.ancestor(
      of: find.text('Cheese'),
      matching: find.byType(SoftCard),
    ));
    expect(cheeseCard.color, primary.withValues(alpha: 0.05));
    expect(cheeseCard.border, isNotNull);
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
