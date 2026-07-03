import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
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

    // Quick mode: footer Save present, split UI present.
    expect(find.text(l10n.save), findsOneWidget);
    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // No per-item split UI: no split-mode selector, no member checkboxes.
    expect(find.byType(AppSegmentedControl<SplitMode>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text(l10n.splitSectionLabel), findsNothing);

    // Info note explaining the share-then-claim model is present.
    expect(find.text(l10n.itemizedInfoCallout), findsOneWidget);

    // Single CTA: the share-for-claiming button — the footer Save is gone.
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
    expect(find.text(l10n.save), findsNothing);
  });

  testWidgets(
      'Quick split has no add-item button; Itemized does (F111)',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick split: no add-item button in either wording. "Add item" is an
    // Itemized-only concept.
    expect(find.text(l10n.addItemByHand), findsNothing);
    expect(find.text(l10n.addNewExpenseEntry), findsNothing);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Itemized still offers the add-item action.
    expect(find.text(l10n.addItemByHand), findsOneWidget);
  });

  testWidgets('Add item by hand appends an item card', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // One item card to start (the seeded entry). The top-level expense
    // name field now reuses the same description hint, so the count is
    // entries + 1 (the top-level inset field).
    expect(find.text(l10n.expenseDescriptionHint), findsNWidgets(2));

    await tester.ensureVisible(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();

    // A second item card's name hint appears (2 entries + 1 top-level).
    expect(find.text(l10n.expenseDescriptionHint), findsNWidgets(3));
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
    expect(find.text(l10n.save), findsNothing);

    // One card, quantity 2 — not two qty-1 unit cards.
    expect(find.text('2x'), findsOneWidget);
    expect(find.text(l10n.itemizedTotalFromItems(1)), findsOneWidget);
  });

  testWidgets(
      'shared-expense item cards seed real line totals, not €0.00 (F146)',
      (tester) async {
    await _pump(tester, expense: _sharedClaimExpense());

    // Unit price seeds the amount field; the line total is 2 × €2.50.
    expect(find.text('2.50'), findsWidgets);
    expect(find.text('= €5.00'), findsOneWidget);
    expect(find.textContaining('€0.00'), findsNothing);
  });

  testWidgets('itemized editor renders in dark mode without throwing',
      (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    final l10n = await _l10n();
    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
