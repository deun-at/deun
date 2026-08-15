import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
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

/// A saved quick expense as `fetchDetail` returns it: one equal-split entry.
/// Single entry + no claim units => the editor opens on the Quick layout.
Expense _quickExpense() {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'e1',
    'group_id': 'g1',
    'name': 'Dinner',
    'expense_date': '2026-01-10',
    'paid_by': 'a@test.com',
    'created_at': '2026-01-10T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': [
      {
        'id': 'ee1',
        'expense_id': 'e1',
        'name': 'Dinner',
        'amount': 20.0,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2026-01-10T10:00:00',
        'expense_entry_share': [
          {
            'expense_entry_id': 'ee1',
            'email': 'a@test.com',
            'display_name': 'Alice',
            'percentage': 50.0,
            'created_at': '2026-01-10T10:00:00',
          },
          {
            'expense_entry_id': 'ee1',
            'email': 'b@test.com',
            'display_name': 'Bob',
            'percentage': 50.0,
            'created_at': '2026-01-10T10:00:00',
          },
        ],
      },
    ],
  });
  return e;
}

/// A saved shared/claim expense: two claim units in distinct item groups, so
/// the editor opens on the Itemized layout.
Expense _itemizedExpense() {
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

Future<void> _pump(
  WidgetTester tester, {
  Expense? expense,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
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
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(group: _group(), expense: expense),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // A NEW expense auto-opens the amount keypad (F100); dismiss it so the
  // editor's own labels are what we assert on.
  if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
    await tester.pumpAndSettle();
  }
}

Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  // AC1 — the reported bug, straight through the widget and against the
  // literal string the user saw.
  testWidgets('editing a quick expense never says "Add expense" (en)', (
    tester,
  ) async {
    await _pump(tester, expense: _quickExpense());
    final l10n = await _l10n(const Locale('en'));

    expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
    expect(find.text(l10n.save), findsOneWidget);

    expect(find.text(l10n.expenseAddButton), findsNothing);
    expect(find.text('Add expense'), findsNothing);
    expect(find.text(l10n.expenseDetailTitleNew), findsNothing);
  });

  // AC1 + AC3 — the German half of the same screen.
  testWidgets('editing a quick expense never says "Ausgabe hinzufügen" (de)', (
    tester,
  ) async {
    await _pump(tester, expense: _quickExpense(), locale: const Locale('de'));
    final de = await _l10n(const Locale('de'));

    expect(
      find.text(de.expenseDetailTitleEdit),
      findsOneWidget,
    ); // Ausgabe bearbeiten
    expect(find.text(de.save), findsOneWidget); // Speichern

    expect(find.text(de.expenseAddButton), findsNothing);
    expect(find.text('Ausgabe hinzufügen'), findsNothing);
    expect(find.text('Add expense'), findsNothing); // not the English fallback
  });

  // AC1 — the sibling surface the contract insisted we cover: the itemized
  // editor's own CTA was equally new-only ("Add & share for claiming").
  testWidgets('editing an itemized expense uses the edit share CTA (en)', (
    tester,
  ) async {
    await _pump(tester, expense: _itemizedExpense());
    final l10n = await _l10n(const Locale('en'));

    expect(find.text(l10n.expenseDetailTitleEdit), findsOneWidget);
    expect(find.text(l10n.expenseSaveAndShareForClaimingEdit), findsOneWidget);

    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);
    expect(find.text('Add & share for claiming'), findsNothing);
    expect(find.text(l10n.expenseAddButton), findsNothing);
  });

  // AC1 + AC3 — German itemized edit.
  testWidgets('editing an itemized expense uses the edit share CTA (de)', (
    tester,
  ) async {
    await _pump(
      tester,
      expense: _itemizedExpense(),
      locale: const Locale('de'),
    );
    final de = await _l10n(const Locale('de'));

    expect(find.text(de.expenseSaveAndShareForClaimingEdit), findsOneWidget);
    expect(find.text(de.expenseSaveAndShareForClaiming), findsNothing);
    expect(find.text('Hinzufügen & zum Beanspruchen teilen'), findsNothing);
  });

  // AC2 — creating is untouched, in both layouts and both locales.
  testWidgets('creating a new expense still reads as adding (en)', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await _l10n(const Locale('en'));

    expect(find.text(l10n.expenseDetailTitleNew), findsOneWidget);
    expect(find.text(l10n.expenseAddButton), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text(l10n.save), findsNothing);
  });

  testWidgets('creating a new expense still reads as adding (de)', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('de'));
    final de = await _l10n(const Locale('de'));

    expect(find.text(de.expenseDetailTitleNew), findsOneWidget); // Neue Ausgabe
    expect(find.text('Ausgabe hinzufügen'), findsOneWidget);
    expect(find.text(de.save), findsNothing);
  });

  // AC2 — the itemized CTA on a NEW expense keeps its add wording; toggling to
  // Itemized must not flip it to the edit verb.
  testWidgets('new expense toggled to Itemized keeps the add share CTA', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await _l10n(const Locale('en'));

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
    expect(find.text(l10n.expenseSaveAndShareForClaimingEdit), findsNothing);
  });
}
