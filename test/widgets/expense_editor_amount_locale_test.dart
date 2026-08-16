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

Group _group(String currencyCode) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.currencyCode = currencyCode;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

Expense _expense(double initialAmount) {
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
      {
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Kiosk',
        'amount': initialAmount,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2026-07-01T10:00:00',
        'expense_entry_share': [
          {
            'expense_entry_id': 'u1',
            'email': 'a@test.com',
            'display_name': 'Alice',
            'percentage': 50.0,
            'created_at': '2026-07-01T10:00:00',
          },
          {
            'expense_entry_id': 'u1',
            'email': 'b@test.com',
            'display_name': 'Bob',
            'percentage': 50.0,
            'created_at': '2026-07-01T10:00:00',
          },
        ],
      },
    ],
  });
  return e;
}

Future<void> pumpEditor(
  WidgetTester tester, {
  required Locale locale,
  required String currencyCode,
  required double initialAmount,
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
            child: ExpenseDetail(
              group: _group(currencyCode),
              expense: _expense(initialAmount),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
    await tester.pumpAndSettle();
  }
}

void main() {
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

  testWidgets('the hero amount is locale-formatted for a German user', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      locale: const Locale('de'),
      currencyCode: 'EUR',
      initialAmount: 12.5,
    );
    expect(find.text('12,50'), findsOneWidget);
    expect(find.text('12.50'), findsNothing);
  });

  testWidgets('the hero amount keeps the English format for an English user', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      locale: const Locale('en'),
      currencyCode: 'EUR',
      initialAmount: 12.5,
    );
    expect(find.text('12.50'), findsOneWidget);
  });

  testWidgets('a JPY group renders the hero with no fractional part', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      locale: const Locale('en'),
      currencyCode: 'JPY',
      initialAmount: 3000,
    );
    expect(find.text('3,000'), findsOneWidget);
    expect(find.text('3,000.00'), findsNothing);
  });

  testWidgets('the hero symbol comes from the group currency', (tester) async {
    await pumpEditor(
      tester,
      locale: const Locale('en'),
      currencyCode: 'JPY',
      initialAmount: 3000,
    );
    expect(find.text('¥'), findsOneWidget);
  });
}
