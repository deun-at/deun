import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/editor/editor_quick_amount.dart';
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

// The editor sits under the group's own ThemeBuilder, but a set of its
// colours and every sheet it opens have always followed the APP's brand theme.
// Every other editor suite colours its group with the brand seed, which makes
// the two themes identical there, so this one uses a group colour that is not
// the brand's.
const _groupSeed = Color(0xFF2E7D32);

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
  g.colorValue = _groupSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

Expense _expense(List<Map<String, dynamic>> entries) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'e1',
    'group_id': 'g1',
    'name': 'Dinner',
    'expense_date': '2026-01-10',
    'paid_by': 'a@test.com',
    'created_at': '2026-01-10T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': entries,
  });
  return e;
}

/// One equal-split entry: opens on the Quick layout.
Expense _quickExpense() => _expense([
  {
    'id': 'ee1',
    'expense_id': 'e1',
    'name': 'Dinner',
    'amount': 20.0,
    'quantity': 1,
    'split_mode': 'equal',
    'created_at': '2026-01-10T10:00:00',
    'expense_entry_share': [
      for (final email in ['a@test.com', 'b@test.com'])
        {
          'expense_entry_id': 'ee1',
          'email': email,
          'display_name': email,
          'percentage': 50.0,
          'created_at': '2026-01-10T10:00:00',
        },
    ],
  },
]);

/// Two claim units in distinct item groups: opens on the Itemized layout.
Expense _itemizedExpense() => _expense([
  for (final (id, name, amount) in [('u1', 'Beer', 2.5), ('u2', 'Wine', 4.0)])
    {
      'id': id,
      'expense_id': 'e1',
      'name': name,
      'amount': amount,
      'quantity': 1,
      'split_mode': 'claim',
      'item_group_id': 'grp-$id',
      'created_at': '2026-01-10T10:00:00',
      'expense_entry_share': const [],
    },
]);

Future<void> _pump(WidgetTester tester, Expense expense) async {
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
            data: _theme(context, kBrandSeed),
            child: ExpenseDetail(group: _group(), expense: expense),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ThemeData _theme(BuildContext context, Color seed) =>
    getThemeData(context, seed, Brightness.light);

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// The two colour schemes under test, plus a guard that they differ in the
/// slots asserted on: a test that cannot tell the themes apart proves nothing.
ColorScheme _brand(WidgetTester tester) =>
    _theme(tester.element(find.byType(Scaffold)), kBrandSeed).colorScheme;

ColorScheme _group0(WidgetTester tester) =>
    _theme(tester.element(find.byType(Scaffold)), _groupSeed).colorScheme;

/// The theme a sheet's own subtree resolves, i.e. the one it was opened with.
ColorScheme _sheetScheme(WidgetTester tester, Type sheet) =>
    Theme.of(tester.element(find.byType(sheet))).colorScheme;

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

  // Slots asserted on are ones the two seeds actually colour differently
  // (primary, primaryContainer, outlineVariant, outline); the neutral
  // onSurface* slots are identical across seeds and prove nothing here.
  testWidgets('quick layout: field border and divider stay on the app theme, '
      'the row chevron on the group theme', (tester) async {
    await _pump(tester, _quickExpense());
    final l10n = await _l10n();
    final brand = _brand(tester);
    final group = _group0(tester);
    expect(brand.primary, isNot(group.primary));
    expect(brand.outlineVariant, isNot(group.outlineVariant));
    expect(brand.outline, isNot(group.outline));

    // Name field: the focus border.
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('expense_name_field')),
        matching: find.byType(TextField),
      ),
    );
    final focused = field.decoration!.focusedBorder as OutlineInputBorder;
    expect(focused.borderSide.color, brand.primary);

    // Paid-by / When: the hairline between the rows ...
    final card = find.ancestor(
      of: find.text(l10n.expenseWhen),
      matching: find.byType(Column),
    );
    final divider = tester.widget<Divider>(
      find.descendant(of: card.first, matching: find.byType(Divider)).first,
    );
    expect(divider.color, brand.outlineVariant.withValues(alpha: 0.5));

    // ... while the row's own chevron has always followed the group.
    final chevron = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(
          of: find.text(l10n.expenseWhen),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.chevron_right),
      ),
    );
    expect(chevron.color, group.outline);
  });

  testWidgets('itemized layout: the info callout stays on the app theme', (
    tester,
  ) async {
    await _pump(tester, _itemizedExpense());
    final l10n = await _l10n();
    final brand = _brand(tester);
    final group = _group0(tester);
    expect(brand.primary, isNot(group.primary));
    expect(brand.primaryContainer, isNot(group.primaryContainer));

    final calloutText = find.text(l10n.itemizedInfoCallout);
    final callout = tester.widget<Container>(
      find.ancestor(of: calloutText, matching: find.byType(Container)).first,
    );
    expect(
      (callout.decoration! as BoxDecoration).color,
      brand.primaryContainer.withValues(alpha: 0.5),
    );
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: calloutText, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.info_outline),
      ),
    );
    expect(icon.color, brand.primary);
  });

  testWidgets('the sheets the quick editor opens take the app theme', (
    tester,
  ) async {
    await _pump(tester, _quickExpense());
    final l10n = await _l10n();
    final brand = _brand(tester);
    expect(brand.primary, isNot(_group0(tester).primary));

    Future<void> openAndCheck(Finder tap, Type sheet) async {
      await tester.ensureVisible(tap);
      await tester.pumpAndSettle();
      await tester.tap(tap);
      await tester.pumpAndSettle();
      expect(
        _sheetScheme(tester, sheet).primary,
        brand.primary,
        reason: '$sheet',
      );
      Navigator.of(tester.element(find.byType(sheet))).pop();
      await tester.pumpAndSettle();
    }

    await openAndCheck(find.text(l10n.expenseWhen), DateOptionsSheet);
    await openAndCheck(find.text(l10n.expensePaidBy), PaidBySheet);
    await openAndCheck(
      find.descendant(
        of: find.byType(EditorQuickAmountSection),
        matching: find.byType(InkWell),
      ),
      AmountKeypadSheet,
    );
  });
}
