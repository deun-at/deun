import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/dashed_ghost_button.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Expense? expense,
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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(group: _group(), expense: expense),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // A new expense auto-opens the amount keypad (F100); these tests exercise the
  // Itemized flow, so dismiss it to reach the underlying editor.
  if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
    await tester.pumpAndSettle();
  }
}

/// A shared itemized expense as fetchDetail returns it: per-unit claim
/// entries (qty 1, split_mode 'claim') grouped by item_group_id, one unit
/// already claimed by Bob.
Expense _sharedClaimExpense() {
  Map<String, dynamic> unit(String id, {List<String> claimers = const []}) => {
        'id': id,
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 2.5,
        'quantity': 1,
        'split_mode': 'claim',
        'item_group_id': 'grp-1',
        'created_at': '2026-07-01T10:00:00',
        'expense_entry_share': claimers
            .map((email) => {
                  'expense_entry_id': id,
                  'email': email,
                  'display_name': email,
                  'percentage': 100.0,
                  'created_at': '2026-07-01T10:00:00',
                })
            .toList(),
      };

  final e = Expense();
  e.loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': [
      unit('u1', claimers: ['b@test.com']),
      unit('u2'),
    ],
  });
  return e;
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

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

  testWidgets('renders the Quick/Itemized top segmented toggle', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    expect(find.byType(AppSegmentedControl<EditorMode>), findsOneWidget);
    expect(find.text(l10n.editorModeQuick), findsOneWidget);
    expect(find.text(l10n.editorModeItemized), findsOneWidget);
  });

  testWidgets('switching to Itemized shows the items list and CTA',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick CTA visible first; itemized CTA not yet.
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Items header, add-item action, info callout, and the claiming CTA.
    expect(find.text(l10n.itemizedItemsLabel), findsOneWidget);
    expect(find.text(l10n.addItemByHand), findsOneWidget);
    expect(find.text(l10n.itemizedInfoCallout), findsOneWidget);
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
  });

  testWidgets(
      'itemized tab shows no per-item split UI and a single share-for-claiming CTA (F118)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick mode: footer "Add expense" CTA present, split UI present (F112).
    expect(find.text(l10n.expenseAddButton), findsOneWidget);
    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // No per-item split UI: no split-mode selector, no member checkboxes.
    expect(find.byType(AppSegmentedControl<SplitMode>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text(l10n.splitSectionLabel), findsNothing);

    // Info note explaining the share-then-claim model is present.
    expect(find.text(l10n.itemizedInfoCallout), findsOneWidget);

    // Single CTA: the share-for-claiming button — the footer quick CTA is gone.
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
    expect(find.text(l10n.expenseAddButton), findsNothing);
  });

  testWidgets('Quick split allocation summary shows no "All set" label (F110)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick mode with the seeded equal split is fully allocated, but the
    // "All set" status label is intentionally not shown here (F110). The
    // numeric split-mode selector still renders, confirming we're on quick.
    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    expect(find.text(l10n.splitAllocatedLabel), findsNothing);
  });

  testWidgets(
      'Quick split has no add-item button; Itemized does (F111)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick split: no add-item button in either wording. "Add item" is an
    // Itemized-only concept. The dashed ghost button is absent too.
    expect(find.text(l10n.addItemByHand), findsNothing);
    expect(find.text(l10n.addNewExpenseEntry), findsNothing);
    expect(find.byType(DashedGhostButton), findsNothing);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Itemized still offers the add-item action, rendered as the F119 dashed
    // ghost button (not a tonal/filled button).
    expect(find.text(l10n.addItemByHand), findsOneWidget);
    expect(find.byType(DashedGhostButton), findsOneWidget);
  });

  testWidgets('Add item by hand appends an item card', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // One item card to start (the seeded entry). Item cards use the F117
    // item-name hint; the top-level expense name field keeps its own
    // description hint (asserted separately below).
    expect(find.text(l10n.itemNameHint), findsOneWidget);
    expect(find.text(l10n.expenseDescriptionHint), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();

    // A second item card's name hint appears.
    expect(find.text(l10n.itemNameHint), findsNWidgets(2));
  });

  testWidgets('switching back to Quick shows the Quick amount card',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorModeQuick));
    await tester.pumpAndSettle();

    // Quick layout's claiming CTA is gone; quick view is back (SoftCard amount).
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);
    expect(find.byType(SoftCard), findsWidgets);
  });

  testWidgets(
      'editing a shared expense regroups claim units into one qty-N item card (F146)',
      (tester) async {
    await _pump(tester, expense: _sharedClaimExpense());
    final l10n = await _l10n();

    // Opens directly in the itemized layout (no toggle tap needed).
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
    expect(find.text(l10n.expenseAddButton), findsNothing);

    // One card, quantity 2 — not two qty-1 unit cards.
    expect(find.text(l10n.itemQtyStepperValue(2)), findsOneWidget);
    expect(find.text(l10n.itemizedTotalFromItems(1)), findsOneWidget);
  });

  testWidgets(
      'shared-expense item cards seed real line totals, not €0.00 (F146)',
      (tester) async {
    await _pump(tester, expense: _sharedClaimExpense());
    final l10n = await _l10n();

    // Unit price seeds the amount field; the line total is 2 × €2.50 = €5.00,
    // which appears twice: the item card's line total + the expense total.
    expect(find.text('2.50'), findsWidgets);
    expect(find.text(l10n.toCurrency(5)), findsNWidgets(2));
    expect(find.textContaining('€0.00'), findsNothing);
  });

  testWidgets(
      'itemized total block is unboxed (no SoftCard) and reads "Total · from N items" (F115)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Copy carries the dot separator and the live item count.
    expect(find.text(l10n.itemizedTotalFromItems(1)), findsOneWidget);
    expect(l10n.itemizedTotalFromItems(1), contains('·'));

    // The total header (anchored on its Scan pill) is not wrapped in a
    // SoftCard — it sits directly on the page background like F103.
    expect(
      find.ancestor(
        of: find.text(l10n.expenseScanShort),
        matching: find.byType(SoftCard),
      ),
      findsNothing,
    );
  });

  testWidgets('itemized editor renders in dark mode without throwing',
      (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    final l10n = await _l10n();
    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // BUG A: the itemized "Add & share for claiming" CTA is the last child inside
  // the scrollable body (only Quick has a pinned footer). The scroll body must
  // keep a bottom inset so the CTA clears the safe area instead of sitting flush
  // against the viewport bottom (regressed by F173's padding: EdgeInsets.zero).
  testWidgets('itemized scroll body keeps a bottom inset so the CTA is reachable',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick mode: the CTA is a pinned footer, so the list needs no bottom inset.
    final quickList = tester.widget<ListView>(find.byType(ListView).first);
    expect(quickList.padding, EdgeInsets.zero,
        reason: 'Quick keeps the F173 zero padding (pinned footer below).');

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Itemized: CTA lives inside the list, so the list must reserve bottom space.
    final itemizedList = tester.widget<ListView>(find.byType(ListView).first);
    final bottomInset =
        itemizedList.padding?.resolve(TextDirection.ltr).bottom ?? 0;
    expect(bottomInset, greaterThan(0),
        reason: 'Itemized CTA is the last scroll child — needs bottom clearance.');
    // The top must stay 0 so the F173 header->toggle gap is not reintroduced.
    expect(itemizedList.padding?.resolve(TextDirection.ltr).top, 0);
  });

  // BUG B: switching itemized -> Quick with 2+ items used to no-op silently —
  // the toggle stayed on Itemized and read as a dead, unpressable control. Quick
  // must always be honored (items collapse to a single entry).
  testWidgets('Quick toggle is honored even with multiple items (collapses)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Add a second item so we are firmly in multi-entry itemized.
    await tester.ensureVisible(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    expect(find.text(l10n.itemNameHint), findsNWidgets(2));

    // Tap Quick — it must switch back, not silently ignore the request.
    await tester.ensureVisible(find.text(l10n.editorModeQuick));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorModeQuick));
    await tester.pumpAndSettle();

    // Quick layout is back: the quick footer CTA is present and pressable,
    // the itemized CTA is gone, and the split UI (quick-only) is restored.
    final addButton = find.text(l10n.expenseAddButton);
    expect(addButton, findsOneWidget);
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);
    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    // The CTA is genuinely pressable (has an onPressed).
    expect(
      tester.widget<PrimaryButton>(
        find.ancestor(of: addButton, matching: find.byType(PrimaryButton)),
      ).onPressed,
      isNotNull,
    );
  });

  // BUG C: the itemized total header lives in the parent; a per-item price/qty
  // edit must recompute it live (it used to only refresh on a mode toggle).
  testWidgets('itemized total updates live when an item quantity changes',
      (tester) async {
    // Seeded shared expense: 1 item, qty 2, unit price 2.50 -> total €5.00.
    await _pump(tester, expense: _sharedClaimExpense());
    final l10n = await _l10n();

    expect(find.text(l10n.toCurrency(5)), findsNWidgets(2)); // line + header

    // Bump quantity 2 -> 3 via the item's qty stepper (no mode toggle).
    await tester.tap(find.bySemanticsLabel(l10n.stepperIncrease).first);
    await tester.pumpAndSettle();

    // Header total recomputes immediately to 3 × €2.50 = €7.50.
    expect(find.text(l10n.toCurrency(7.5)), findsNWidgets(2));
    expect(find.text(l10n.toCurrency(5)), findsNothing);
  });

  // BUG D: itemized item rows must render inside ONE joined SoftCard, not a
  // card-in-card (a per-row SoftCard nested inside an outer CardColumn/Card).
  testWidgets('itemized items render in a single card, not nested cards',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Add a second item so a nested outer/inner wrapper would be obvious.
    await tester.ensureVisible(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    expect(find.text(l10n.itemNameHint), findsNWidgets(2));

    // Each item's content sits under exactly ONE SoftCard — no card-in-card.
    for (final field in find.text(l10n.itemNameHint).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(field.widget),
          matching: find.byType(SoftCard),
        ),
        findsOneWidget,
        reason: 'An item row must have a single SoftCard ancestor, not nested.',
      );
    }
  });
}
