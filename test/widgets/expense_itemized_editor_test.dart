import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/widgets/category_selector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
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
            data: getThemeData(
              context,
              kBrandSeed,
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
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
        .map(
          (email) => {
            'expense_entry_id': id,
            'email': email,
            'display_name': email,
            'percentage': 100.0,
            'created_at': '2026-07-01T10:00:00',
          },
        )
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

/// A saved itemized (shared/claim) expense carrying an expense-level
/// [category], as fetchDetail returns it.
Expense _itemizedExpenseWithCategory(String category) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'category': category,
    'expense_entry': [
      {
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 2.5,
        'quantity': 1,
        'split_mode': 'claim',
        'item_group_id': 'grp-1',
        'created_at': '2026-07-01T10:00:00',
        'expense_entry_share': const [],
      },
    ],
  });
  return e;
}

/// A saved itemized expense with two distinct item groups (Beer €2.50 and
/// Wine €4.00), so the editor opens with two item cards whose line totals sum
/// to €6.50 — used to prove the Itemized → Quick collapse seeds the summed
/// total, not the first item's amount (scan-split-even).
Expense _twoItemExpense() {
  Map<String, dynamic> unit(
    String id,
    String name,
    double amount,
    String grp,
  ) => {
    'id': id,
    'expense_id': 'exp1',
    'name': name,
    'amount': amount,
    'quantity': 1,
    'split_mode': 'claim',
    'item_group_id': grp,
    'created_at': '2026-07-01T10:00:00',
    'expense_entry_share': const [],
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
      unit('u1', 'Beer', 2.5, 'grp-1'),
      unit('u2', 'Wine', 4.0, 'grp-2'),
    ],
  });
  return e;
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

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

  testWidgets('renders the Quick/Itemized top segmented toggle', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await _l10n();

    expect(find.byType(AppSegmentedControl<EditorMode>), findsOneWidget);
    expect(find.text(l10n.editorModeQuick), findsOneWidget);
    expect(find.text(l10n.editorModeItemized), findsOneWidget);
  });

  testWidgets('switching to Itemized shows the items list and CTA', (
    tester,
  ) async {
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
    },
  );

  testWidgets(
    'Quick split allocation summary shows no "All set" label (F110)',
    (tester) async {
      await _pump(tester);
      final l10n = await _l10n();

      // Quick mode with the seeded equal split is fully allocated, but the
      // "All set" status label is intentionally not shown here (F110). The
      // numeric split-mode selector still renders, confirming we're on quick.
      expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
      expect(find.text(l10n.splitAllocatedLabel), findsNothing);
    },
  );

  testWidgets('Quick split has no add-item button; Itemized does (F111)', (
    tester,
  ) async {
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

  testWidgets('switching back to Quick shows the Quick amount card', (
    tester,
  ) async {
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
    },
  );

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
    },
  );

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
    },
  );

  testWidgets('itemized editor renders in dark mode without throwing', (
    tester,
  ) async {
    await _pump(tester, brightness: Brightness.dark);
    final l10n = await _l10n();
    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // cosmetic-round-2026-07 (CTA bar): the itemized "Add & share for claiming"
  // CTA is fixed to the bottom on an opaque surface bar — a sibling of the
  // scrollable list, NOT the last scroll child — so it stays put instead of
  // scrolling with the content, and the list content is not hidden behind it.
  testWidgets('itemized CTA is pinned in the footer, not a scroll child', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    final ctaLabel = find.text(l10n.expenseSaveAndShareForClaiming);
    // The CTA renders exactly once...
    expect(ctaLabel, findsOneWidget);
    // ...but NOT inside the scrolling ListView — it is pinned below it.
    expect(
      find.descendant(of: find.byType(ListView), matching: ctaLabel),
      findsNothing,
      reason: 'The claiming CTA must be the pinned footer, not a scroll child.',
    );

    // The footer bar is opaque and surface-colored (per the design handoff).
    // Walk the Container ancestors and pick the one painted with surface.
    final scheme = Theme.of(tester.element(ctaLabel)).colorScheme;
    final footerFinder = find.ancestor(
      of: ctaLabel,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.color == scheme.surface,
      ),
    );
    expect(
      footerFinder,
      findsOneWidget,
      reason: 'The pinned CTA sits on an opaque surface-colored bar.',
    );

    // Because the footer is a Column sibling (not an overlay), the list is not
    // hidden behind it — the list itself needs no bottom inset to clear a CTA.
    // Top stays 0 so the header->toggle gap is not reintroduced (F173).
    final itemizedList = tester.widget<ListView>(find.byType(ListView).first);
    expect(itemizedList.padding?.resolve(TextDirection.ltr).top, 0);

    // The footer sits below the scroll list (its top edge is at/under the
    // list's bottom edge) — i.e. it is genuinely pinned to the bottom.
    final listBottom = tester.getRect(find.byType(ListView).first).bottom;
    final footerTop = tester.getRect(footerFinder).top;
    expect(footerTop, greaterThanOrEqualTo(listBottom - 0.5));
  });

  // cosmetic-round-2026-07 (paid-by/when block): in the itemized layout the
  // "Paid by" and "When" fields render as ONE connected card with the hairline
  // divider between them — the same block the quick layout uses — instead of
  // two separate spaced cards.
  testWidgets(
    'itemized Paid-by and When are one connected card with a divider',
    (tester) async {
      await _pump(tester);
      final l10n = await _l10n();

      await tester.tap(find.text(l10n.editorModeItemized));
      await tester.pumpAndSettle();

      final paidByLabel = find.text(l10n.expensePaidBy);
      final whenLabel = find.text(l10n.expenseWhen);
      expect(paidByLabel, findsOneWidget);
      expect(whenLabel, findsOneWidget);

      // Both rows share a SINGLE SoftCard ancestor (one connected block).
      final paidCard = find
          .ancestor(of: paidByLabel, matching: find.byType(SoftCard))
          .evaluate()
          .first
          .widget;
      final whenCard = find
          .ancestor(of: whenLabel, matching: find.byType(SoftCard))
          .evaluate()
          .first
          .widget;
      expect(
        identical(paidCard, whenCard),
        isTrue,
        reason: 'Paid-by and When must live in the same connected card.',
      );

      // That shared card carries the small connecting hairline between the rows.
      expect(
        find.descendant(
          of: find.byWidget(paidCard),
          matching: find.byType(Divider),
        ),
        findsOneWidget,
      );
    },
  );

  // cosmetic-round-2026-07 (quick split grid): the quick-split section aligns to
  // the same 16px horizontal grid as the other form sections — its trailing
  // inset used to be 8, leaving the section offset 8px to the right.
  testWidgets('quick split section aligns to the 16px content grid', (
    tester,
  ) async {
    await _pump(tester);

    // Quick mode by default renders the single-entry ExpenseEntryWidget.
    final entryPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(ExpenseEntryWidget),
            matching: find.byType(Padding),
          )
          .first,
    );
    final insets = entryPadding.padding.resolve(TextDirection.ltr);
    expect(insets.left, 16);
    expect(insets.right, 16);
  });

  // BUG B: switching itemized -> Quick with 2+ items used to no-op silently —
  // the toggle stayed on Itemized and read as a dead, unpressable control. Quick
  // must always be honored (items collapse to a single entry).
  testWidgets('Quick toggle is honored even with multiple items (collapses)', (
    tester,
  ) async {
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
      tester
          .widget<PrimaryButton>(
            find.ancestor(of: addButton, matching: find.byType(PrimaryButton)),
          )
          .onPressed,
      isNotNull,
    );
  });

  // BUG C: the itemized total header lives in the parent; a per-item price/qty
  // edit must recompute it live (it used to only refresh on a mode toggle).
  testWidgets('itemized total updates live when an item quantity changes', (
    tester,
  ) async {
    // Seeded shared expense: 1 item, qty 2, unit price 2.50 -> total €5.00.
    await _pump(tester, expense: _sharedClaimExpense());
    final l10n = await _l10n();

    expect(find.text(l10n.toCurrency(5)), findsNWidgets(2)); // line + header

    // Bump quantity 2 -> 3 via the item's qty stepper (no mode toggle).
    // Scroll it into view first: the expense-level category row pushes the item
    // card below the fold in the test viewport.
    await tester.ensureVisible(
      find.bySemanticsLabel(l10n.stepperIncrease).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.stepperIncrease).first);
    await tester.pumpAndSettle();

    // Header total recomputes immediately to 3 × €2.50 = €7.50.
    expect(find.text(l10n.toCurrency(7.5)), findsNWidgets(2));
    expect(find.text(l10n.toCurrency(5)), findsNothing);
  });

  // BUG D: itemized item rows must render inside ONE joined SoftCard, not a
  // card-in-card (a per-row SoftCard nested inside an outer CardColumn/Card).
  testWidgets('itemized items render in a single card, not nested cards', (
    tester,
  ) async {
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

  // itemized-expense-categories: the itemized layout exposes the same
  // category selector as the quick layout (revisits F116).
  testWidgets('Itemized layout exposes a category selector', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    expect(find.byType(CategorySelector), findsOneWidget);
    expect(find.text(l10n.categoryLabel), findsOneWidget);
  });

  // itemized-expense-categories: an itemized expense saved with category X
  // reads back as X (not "Other"). The form value here is exactly the map
  // ExpenseDetail hands to ExpenseRepository.saveAll, which persists
  // category.name; statistics group on the same expense.category.
  testWidgets('itemized expense reads its saved category back (not Other)', (
    tester,
  ) async {
    await _pump(tester, expense: _itemizedExpenseWithCategory('food'));
    final l10n = await _l10n();

    // Opens directly in the itemized layout for a shared/claim expense.
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);

    // The selector shows the saved category, not "Other".
    expect(find.text(l10n.categoryFood), findsOneWidget);
    expect(find.text(l10n.categoryOther), findsNothing);

    // The saved form map feeding ExpenseRepository.saveAll carries the
    // ExpenseCategory value (saveAll persists category.name). save() mirrors
    // the saveAndValidate() the real save path runs before reading value.
    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    formState.save();
    expect(formState.value['category'], ExpenseCategory.food);
  });

  // itemized-expense-categories: an itemized expense saved without a category
  // still reads back as "Other" — no migration, null stays null.
  testWidgets('itemized expense without a category reads back as Other', (
    tester,
  ) async {
    await _pump(tester, expense: _sharedClaimExpense());
    final l10n = await _l10n();

    expect(find.text(l10n.categoryOther), findsOneWidget);
    // An uncategorized expense loads (fromString(null)) as ExpenseCategory.other
    // and reads back as Other — statistics group it under 'other'. No migration.
    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    formState.save();
    expect(formState.value['category'], ExpenseCategory.other);
  });

  // itemized-expense-categories: scanning a receipt auto-detects the category
  // from the merchant name in the itemized layout, same as the quick layout.
  // Editing the merchant name drives the same CategoryDetector hook.
  testWidgets('itemized layout auto-detects category from the merchant name', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Type a merchant name the detector maps to Groceries (keyword "lidl").
    final nameField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == l10n.expenseDescriptionHint,
    );
    await tester.enterText(nameField, 'Lidl');
    await tester.pumpAndSettle();

    // The category is auto-detected and written to the form field.
    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    formState.save();
    expect(formState.value['category'], ExpenseCategory.groceries);
    expect(find.text(l10n.categoryGroceries), findsOneWidget);
  });

  // scan-split-even: collapsing a multi-item itemized expense (as a scan
  // produces) into Quick must seed the expense amount with the SUM of every
  // item line total — €2.50 + €4.00 = €6.50 — not the first item's €2.50 that
  // the old collapse kept while silently dropping the rest. The user is warned
  // that per-item detail merged into one amount.
  testWidgets(
    'collapsing a multi-item itemized expense to Quick seeds the summed total',
    (tester) async {
      await _pump(tester, expense: _twoItemExpense());
      final l10n = await _l10n();

      // Opens itemized with two item cards; header already sums to €6.50.
      expect(find.text(l10n.itemizedTotalFromItems(2)), findsOneWidget);
      expect(find.text(l10n.toCurrency(6.5)), findsWidgets);

      // Switch to Quick — the items collapse into one expense-level amount.
      await tester.ensureVisible(find.text(l10n.editorModeQuick));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editorModeQuick));
      await tester.pumpAndSettle();

      // Quick layout is back, seeded with the SUMMED total (€6.50), not the
      // first item's €2.50.
      expect(find.text(l10n.expenseAddButton), findsOneWidget);
      expect(find.text('6.50'), findsOneWidget);
      expect(find.text('2.50'), findsNothing);

      // The collapse warned the user that item detail merged into one amount.
      expect(find.text(l10n.editorModeCollapseNotice), findsOneWidget);
    },
  );
}
