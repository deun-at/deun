import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/category_selector.dart';
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

ExpenseEntry _entry(int index) => ExpenseEntry(index: index)
  ..id = 'entry$index'
  ..splitMode = 'equal'
  ..name = 'Dinner'
  ..amount = 30
  ..quantity = 1
  ..itemGroupId = null;

Expense _expense() {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = 30;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.groupMemberShareStatistic = {};
  e.expenseEntries = {'entry0': _entry(0)};
  return e;
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Expense? expense,
  bool dismissKeypad = true,
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
            // ExpenseDetail wraps itself in a ThemeBuilder that inherits this
            // ambient brightness.
            child: ExpenseDetail(group: _group(), expense: expense),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // A new expense auto-opens the amount keypad (F100). Dismiss it so the
  // underlying editor assertions run against the visible page.
  if (dismissKeypad && find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    final ctx = tester.element(find.byType(AmountKeypadSheet));
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
  }
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

  testWidgets('renders the restyled Quick editor tiles', (tester) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Description / title field hint (v3: inset field, reuses description hint).
    expect(find.text(l10n.expenseDescriptionHint), findsWidgets);

    // F103: the amount is unboxed — no SoftCard wraps the € amount text.
    final amountText = find.text('0.00');
    expect(amountText, findsOneWidget);
    expect(
      find.ancestor(of: amountText, matching: find.byType(SoftCard)),
      findsNothing,
      reason: 'the quick-split amount must sit directly on the page background',
    );

    // F103: a per-person split preview sits under the amount.
    expect(find.text(l10n.expenseSplitEach(l10n.toCurrency(0))), findsOneWidget);

    // F103/F113: no "Details" section header in the quick block.
    expect(find.text(l10n.expenseDetailsLabel), findsNothing);

    // F103/F114: the date row is labelled "When", and Paid by / When live in a
    // single card (one SoftCard around both rows).
    expect(find.text(l10n.expensePaidBy), findsWidgets);
    expect(find.text(l10n.expenseWhen), findsOneWidget);
    final paidByLabel = find.text(l10n.expensePaidBy).first;
    final whenLabel = find.text(l10n.expenseWhen);
    final sharedCard = find.ancestor(
      of: paidByLabel,
      matching: find.byType(SoftCard),
    );
    expect(sharedCard, findsWidgets);
    expect(
      find.descendant(of: sharedCard.first, matching: whenLabel),
      findsOneWidget,
      reason: 'Paid by and When must share one non-spaced list card',
    );

    // Quick mode surfaces the category as a centered compact tile above the
    // amount (v3 design_08/09), not a labelled details row.
    expect(find.byType(CategorySelector), findsOneWidget);
  });

  testWidgets('tapping the date tile opens the date options sheet',
      (tester) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.dragUntilVisible(
      find.text(l10n.expenseWhen),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.expenseWhen));
    await tester.pumpAndSettle();

    // The restyled date sheet shows quick options, not the platform picker yet.
    // ("Today" can also be the tile's current value, so scope to the sheet.)
    final sheet = find.byType(DateOptionsSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(l10n.dateYesterday)),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(l10n.datePickCustom)),
        findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('"Pick a date…" in the date sheet opens the platform picker',
      (tester) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.dragUntilVisible(
      find.text(l10n.expenseWhen),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.expenseWhen));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.datePickCustom));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new expense auto-opens the amount keypad sheet (F100)',
      (tester) async {
    await _pump(tester, dismissKeypad: false);
    expect(find.byType(AmountKeypadSheet), findsOneWidget);
  });

  testWidgets('editing an existing expense does NOT auto-open the keypad',
      (tester) async {
    await _pump(tester, expense: _expense(), dismissKeypad: false);
    expect(find.byType(AmountKeypadSheet), findsNothing);
  });
}
