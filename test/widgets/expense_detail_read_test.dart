import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
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

ExpenseEntry _entry(int index) => ExpenseEntry(index: index);

Expense _expense({
  required int entryCount,
  required Map<String, double> shareStat,
  double amount = 30,
  String paidBy = 'a@test.com',
  ExpenseCategory? category = ExpenseCategory.food,
}) {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = amount;
  e.paidBy = paidBy;
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = category;
  e.groupMemberShareStatistic = shareStat;
  e.expenseEntries = {
    for (var i = 0; i < entryCount; i++) 'entry$i': _entry(i),
  };
  return e;
}

Future<void> _pump(
  WidgetTester tester,
  Expense expense, {
  Brightness brightness = Brightness.light,
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
            child: ExpenseDetailRead(group: _group(), expense: expense),
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

  testWidgets('summary card shows title, total, payer and category', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text(l10n.toCurrency(20)), findsWidgets);
    expect(find.text(l10n.expensePaidBy), findsWidgets);
    expect(find.text(l10n.expenseYourNetLabel), findsOneWidget);
    // Category tag.
    expect(find.text(ExpenseCategory.food.getDisplayName(l10n)), findsOneWidget);
    expect(find.text(l10n.expenseBreakdownLabel), findsOneWidget);
    expect(find.byType(SoftCard), findsWidgets);
  });

  testWidgets('Edit and Delete actions are present', (tester) async {
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('per-member breakdown renders a row per involved member',
      (tester) async {
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('Review & claim banner shows for an itemized expense',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 3,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 30,
      ),
    );

    expect(find.text(l10n.expenseReviewClaimTitle), findsOneWidget);
  });

  testWidgets('Review & claim banner is absent for a quick expense',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _expense(
        entryCount: 1,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 20,
      ),
    );

    expect(find.text(l10n.expenseReviewClaimTitle), findsNothing);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      _expense(
        entryCount: 3,
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
        amount: 30,
      ),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
