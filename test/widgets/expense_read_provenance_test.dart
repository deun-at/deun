import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
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

ExpenseEntry _entry(int index, {double? originalAmount}) =>
    ExpenseEntry(index: index)
      ..splitMode = 'equal'
      ..quantity = 1
      ..originalAmount = originalAmount;

/// A JPY 3000 expense converted at 0.0058 into a 17.40 EUR ledger amount.
Expense convertedExpense({Map<String, double>? shareStat}) {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Ramen';
  e.amount = 17.40;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-08-16';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = ExpenseCategory.food;
  e.originalCurrencyCode = 'JPY';
  e.conversionRate = 0.0058;
  e.rateDate = '2026-08-16';
  e.groupMemberShareStatistic =
      shareStat ?? const {'a@test.com': 8.70, 'b@test.com': 8.70};
  e.expenseEntries = {'u1': _entry(0, originalAmount: 3000)};
  return e;
}

Expense plainEurExpense() {
  final e = Expense();
  e.id = 'e2';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = 20;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-08-16';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = ExpenseCategory.food;
  e.groupMemberShareStatistic = const {'a@test.com': 10, 'b@test.com': 10};
  e.expenseEntries = {'u1': _entry(0)};
  return e;
}

Future<void> pumpRead(WidgetTester tester, {required Expense expense}) async {
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
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetailRead(
              group: _group(),
              expense: expense,
              loadGroupPaybacks: (_) async => const [],
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

  testWidgets('a converted expense shows the amount AS ENTERED', (
    tester,
  ) async {
    await pumpRead(tester, expense: convertedExpense());
    expect(
      find.byKey(const ValueKey('expense_original_amount')),
      findsOneWidget,
    );
    // Code-qualified: "¥" is shared with CNY, so it cannot identify a currency
    // on its own (see formatMoney).
    expect(find.text('JPY 3,000'), findsOneWidget);
  });

  testWidgets('the provenance rows are labelled, not left to be inferred', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpRead(tester, expense: convertedExpense());
    expect(find.text(l10n.expenseProvenanceEntered), findsOneWidget);
    expect(find.text(l10n.expenseProvenanceRate), findsOneWidget);
  });

  testWidgets('the big figure stays the LEDGER value in the group currency', (
    tester,
  ) async {
    await pumpRead(tester, expense: convertedExpense());
    expect(find.text('EUR 17.40'), findsOneWidget);
  });

  testWidgets('the applied rate states its DIRECTION and its date', (
    tester,
  ) async {
    await pumpRead(tester, expense: convertedExpense());
    // A bare "0.0058" can be read in either direction; naming both currencies
    // is the whole point, and the rate keeps its own precision rather than
    // being rounded to EUR's two digits (which would render it as 0.01).
    expect(find.text('1 JPY = 0.0058 EUR · 16.08.2026'), findsOneWidget);
  });

  testWidgets('an unconverted expense shows no provenance rows at all', (
    tester,
  ) async {
    await pumpRead(tester, expense: plainEurExpense());
    expect(find.byKey(const ValueKey('expense_original_amount')), findsNothing);
    expect(find.byKey(const ValueKey('expense_rate_applied')), findsNothing);
  });

  testWidgets('a 0-decimal entry currency renders no fractional part', (
    tester,
  ) async {
    await pumpRead(tester, expense: convertedExpense());
    expect(find.textContaining('JPY 3,000.00'), findsNothing);
  });

  testWidgets(
    'the per-member breakdown is unchanged — it reads the ledger value only',
    (tester) async {
      // 17.40 split two ways is 8.70 each; the original 3000 must appear nowhere
      // in the breakdown.
      await pumpRead(
        tester,
        expense: convertedExpense(
          shareStat: const {'a@test.com': 8.70, 'b@test.com': 8.70},
        ),
      );
      expect(find.text('EUR 8.70'), findsNWidgets(2));
      expect(find.textContaining('1,500'), findsNothing);
    },
  );
}
