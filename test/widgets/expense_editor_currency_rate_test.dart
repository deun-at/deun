import 'dart:convert';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
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

Expense _expense(
  double initialAmount, {
  String? originalCurrency,
  double? rate,
  String? rateDate,
  double? originalAmount,
  String splitMode = 'equal',
  double? fixedAmount,
  double? originalFixedAmount,
}) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'original_currency_code': originalCurrency,
    'conversion_rate': rate,
    'rate_date': rateDate,
    'expense_entry': [
      {
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Kiosk',
        'amount': initialAmount,
        'original_amount': originalCurrency != null
            ? (originalAmount ?? 3000.0)
            : null,
        'quantity': 1,
        'split_mode': splitMode,
        'created_at': '2026-07-01T10:00:00',
        'expense_entry_share': [
          for (final entry in const {
            'a@test.com': 'Alice',
            'b@test.com': 'Bob',
          }.entries)
            {
              'expense_entry_id': 'u1',
              'email': entry.key,
              'display_name': entry.value,
              'percentage': 50.0,
              'fixed_amount': fixedAmount,
              'original_fixed_amount': originalFixedAmount,
              'created_at': '2026-07-01T10:00:00',
            },
        ],
      },
    ],
  });
  return e;
}

/// A JPY 3000 expense, converted at 0.0058 into a 17.40 EUR ledger amount.
Expense convertedExpense() => _expense(
  17.40,
  originalCurrency: 'JPY',
  rate: 0.0058,
  rateDate: '2026-08-16',
);

/// A CHF 4.50 expense at 0.9432 (ledger 4.24) split EXACT: 2.25 CHF a head,
/// stored as 2.12 EUR in `fixed_amount` and 2.25 CHF in
/// `original_fixed_amount`.
Expense convertedExactExpense() => _expense(
  4.24,
  originalCurrency: 'CHF',
  rate: 0.9432,
  rateDate: '2026-08-16',
  originalAmount: 4.50,
  splitMode: 'exact',
  fixedAmount: 2.12,
  originalFixedAmount: 2.25,
);

/// A CHF 100 expense at 0.9432 (ledger 94.32) — a converted expense whose
/// currency can be switched away from and back to.
Expense convertedChfExpense() => _expense(
  94.32,
  originalCurrency: 'CHF',
  rate: 0.9432,
  rateDate: '2026-08-16',
  originalAmount: 100,
);

/// One captured [ExpenseRepository.saveAll] call.
class SavedExpense {
  SavedExpense(this.formValue, this.currency, this.conversion);

  final Map<String, dynamic> formValue;
  final Currency currency;
  final ExpenseConversion? conversion;

  /// The entered unit price of [index], as the repository would parse it.
  double enteredAmount(int index) =>
      double.parse(formValue['expense_entry[$index][amount]'].toString());
}

Map<String, dynamic> _entryJson({
  required String id,
  required double amount,
  double? originalAmount,
  String splitMode = 'equal',
  String? itemGroupId,
}) => {
  'id': id,
  'expense_id': 'exp1',
  'name': 'Beer',
  'amount': amount,
  'original_amount': originalAmount,
  'quantity': 1,
  'split_mode': splitMode,
  'item_group_id': itemGroupId,
  'created_at': '2026-07-01T10:00:00',
  'expense_entry_share': splitMode == 'claim'
      ? const []
      : [
          {
            'expense_entry_id': id,
            'email': 'a@test.com',
            'display_name': 'Alice',
            'percentage': 100.0,
            'created_at': '2026-07-01T10:00:00',
          },
        ],
};

/// An itemized expense in the group's own currency, one entry per amount.
Expense _itemizedExpense(List<double> amounts) => Expense()
  ..loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': [
      for (var i = 0; i < amounts.length; i++)
        _entryJson(id: 'u$i', amount: amounts[i]),
    ],
  });

/// A CHF 10.00 x3 claim line at 0.9432: three units of 9.44 / 9.43 / 9.43
/// summing to the 28.30 EUR the ledger holds. The editor regroups it into one
/// qty-3 card seeded from the 10.00 entered unit price.
Expense convertedClaimExpense() => Expense()
  ..loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'original_currency_code': 'CHF',
    'conversion_rate': 0.9432,
    'rate_date': '2026-08-16',
    'expense_entry': [
      _entryJson(
        id: 'u1',
        amount: 9.44,
        originalAmount: 10,
        splitMode: 'claim',
        itemGroupId: 'i1',
      ),
      _entryJson(
        id: 'u2',
        amount: 9.43,
        originalAmount: 10,
        splitMode: 'claim',
        itemGroupId: 'i1',
      ),
      _entryJson(
        id: 'u3',
        amount: 9.43,
        originalAmount: 10,
        splitMode: 'claim',
        itemGroupId: 'i1',
      ),
    ],
  });

late _FakePrefs _prefs;

/// In-memory stand-in for the async_preferences platform channel, mirroring
/// test/provider/sticky_rate_test.dart's fake.
class _FakePrefs {
  final Map<String, String> values = {};

  void install() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('async_preferences'), (
          call,
        ) async {
          final args = call.arguments as List;
          switch (call.method) {
            case 'get_string':
              return values[args[1] as String];
            case 'set_string':
              values[args[1] as String] = args[2] as String;
              return true;
            case 'remove':
              values.remove(args[1] as String);
              return true;
          }
          return null;
        });
  }
}

/// The code shown in the editor's "Entered in" row.
///
/// Targeted rather than a bare `find.text(code)`: the amount hero renders the
/// same code beside the figure, so an unqualified finder matches twice.
Finder _entryCurrencyLabel(String code) => find.descendant(
  of: find.byKey(const ValueKey('expense_entry_currency')),
  matching: find.text(code),
);

Future<void> _pickCurrency(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const ValueKey('expense_entry_currency')));
  await tester.pumpAndSettle();
  // The picker sheet lists 30 currencies in a scrollable body; a currency
  // further down the ECB order (e.g. CHF) is off-screen at the default test
  // viewport, so scroll it into view before tapping — an out-of-bounds tap
  // silently misses and leaves the sheet open, blocking every later tap.
  // Look the row up by the label the picker actually renders: CHF and RON are
  // their own symbols, so they have no " · " half to match on.
  final target = find.text(Currency.fromCode(code).code);
  await tester.scrollUntilVisible(
    target,
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A prefill that never answers. The default for both harnesses, so these tests
/// exercise the manual rate field exactly as they always have — without it, the
/// real [fetchRate] would reach for `functions.invoke` against the fake
/// Supabase URL and let a network stub decide what they see.
Future<RateQuote?> _noPrefill({
  required Currency base,
  required Currency quote,
  required DateTime date,
}) async => null;

Future<void> pumpEditor(
  WidgetTester tester, {
  required String currencyCode,
  double? initialAmount,
  Expense? expense,
  RateLookup? lookupRate,
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
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(
              group: _group(currencyCode),
              expense: expense ?? _expense(initialAmount ?? 12.5),
              lookupRate: lookupRate ?? _noPrefill,
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

/// Public re-exports of this file's harness, so a sibling suite can drive the
/// same editor without a second copy of these fixtures. The call sites in this
/// file keep the private names; only the seam is new.
Future<void> pickCurrency(WidgetTester tester, String code) =>
    _pickCurrency(tester, code);

/// Taps the save CTA and drains the success SnackBar's timer.
Future<void> saveEditor(WidgetTester tester) => _save(tester);

/// The in-memory `async_preferences` store behind the sticky-rate provider.
Map<String, String> get prefsValues => _prefs.values;

/// Installs a fresh fake preference store. Call from `setUp`.
void installFakePrefs() {
  _prefs = _FakePrefs()..install();
}

/// Initialises the mocked Supabase client the editor reaches for. Call from
/// `setUpAll`.
Future<void> initTestSupabase() async {
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
}

/// Pumps the editor with its WRITE stubbed, on a pushed route so a successful
/// save can pop back, and returns the list the stub records into.
///
/// The save payload is where the "frozen" criterion is actually decided: the
/// form values are entry-currency amounts and the [ExpenseConversion] is what
/// the provenance columns and every conversion are written from. Building an
/// [ExpenseConversion] by hand in a unit test asserts nothing about the editor
/// carrying its loaded rate and rate date through an unrelated edit, so the
/// editor has to hand the payload out.
Future<List<SavedExpense>> pumpEditorWithSaveSeam(
  WidgetTester tester, {
  required String currencyCode,
  Expense? expense,
  RateLookup? lookupRate,
}) async {
  final captured = <SavedExpense>[];
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
        // '/edit' builds the stack ['/', '/edit'], so the post-save pop has
        // somewhere to land instead of emptying the navigator.
        initialRoute: '/edit',
        routes: {
          '/': (context) => const Scaffold(body: Text('BEHIND')),
          '/edit': (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(
              group: _group(currencyCode),
              expense: expense ?? _expense(12.5),
              lookupRate: lookupRate ?? _noPrefill,
              saveExpense:
                  (
                    context,
                    groupId,
                    expenseId,
                    formResponse, {
                    required currency,
                    conversion,
                  }) async {
                    captured.add(
                      SavedExpense(
                        Map<String, dynamic>.from(formResponse),
                        currency,
                        conversion,
                      ),
                    );
                  },
            ),
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

/// Taps the editor's save CTA and drains the success SnackBar's timer.
Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton).last);
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  setUpAll(initTestSupabase);

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(installFakePrefs);

  testWidgets(
    'the editor defaults to the group currency and shows no rate field',
    (tester) async {
      await pumpEditor(tester, currencyCode: 'EUR');
      expect(_entryCurrencyLabel('EUR'), findsOneWidget);
      expect(find.byKey(const ValueKey('expense_rate_field')), findsNothing);
    },
  );

  testWidgets(
    'choosing a different currency reveals the rate field and the required hint',
    (tester) async {
      await pumpEditor(tester, currencyCode: 'EUR');
      await _pickCurrency(tester, 'JPY');
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const ValueKey('expense_rate_field')), findsOneWidget);
      expect(find.text(l10n.expenseRateRequired), findsOneWidget);
      expect(find.byKey(const ValueKey('expense_rate_preview')), findsNothing);
    },
  );

  testWidgets(
    'an EMPTY rate field still states which way round the rate goes',
    (tester) async {
      // The first foreign expense in a group has no remembered rate, so the
      // field is empty and unfocused — and that is exactly when the user needs
      // to know whether to type CHF-per-EUR or EUR-per-CHF. Flutter hides
      // prefix and suffix on an empty unfocused field unless the label is
      // pinned, so this is a real regression risk, not a theoretical one.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpEditor(tester, currencyCode: 'EUR');
      await _pickCurrency(tester, 'JPY');

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
            .controller
            ?.text,
        isEmpty,
        reason: 'the precondition: no remembered rate to prefill',
      );
      // Presence is not visibility: InputDecorator BUILDS prefix and suffix
      // either way and fades them with an AnimatedOpacity, so find.text alone
      // would pass against an invisible prefix. Assert the opacity.
      for (final text in ['${l10n.expenseRatePrefix('JPY')} ', ' EUR']) {
        final finder = find.text(text);
        expect(finder, findsOneWidget);
        final opacities = tester
            .widgetList<AnimatedOpacity>(
              find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)),
            )
            .map((w) => w.opacity);
        expect(
          opacities.every((o) => o == 1.0),
          isTrue,
          reason: '"$text" is built but faded out: ${opacities.toList()}',
        );
      }
    },
  );

  testWidgets('entering a rate shows a live preview in the GROUP currency', (
    tester,
  ) async {
    await pumpEditor(tester, currencyCode: 'EUR', initialAmount: 3000);
    await _pickCurrency(tester, 'JPY');
    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.0058',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('EUR 17.40'), findsOneWidget);
  });

  testWidgets(
    'emptying the rate field restores the hint — no "= €0.00" preview, no Reset',
    (tester) async {
      await pumpEditor(tester, currencyCode: 'EUR', initialAmount: 3000);
      await _pickCurrency(tester, 'JPY');
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '0.0058',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('expense_rate_preview')),
        findsOneWidget,
      );

      // The formatter rewrites an empty field to "0"; parseConversionRate must
      // map that to null.
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '',
      );
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const ValueKey('expense_rate_preview')), findsNothing);
      expect(find.textContaining('EUR 0.00'), findsNothing);
      expect(find.text(l10n.expenseRateRequired), findsOneWidget);
      expect(find.byKey(const ValueKey('expense_rate_reset')), findsNothing);
    },
  );

  testWidgets('saving a foreign-currency expense with no rate is REFUSED', (
    tester,
  ) async {
    await pumpEditor(tester, currencyCode: 'EUR', initialAmount: 3000);
    await _pickCurrency(tester, 'JPY');
    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // The refusal snackbar shows and the editor is still on screen — no write,
    // no pop, and above all no 1:1 fallback.
    expect(find.text(l10n.expenseRateRequired), findsWidgets);
    expect(find.byType(ExpenseDetail), findsOneWidget);
  });

  testWidgets('the amount hero and keypad follow the ENTRY currency', (
    tester,
  ) async {
    await pumpEditor(tester, currencyCode: 'EUR', initialAmount: 3000);
    await _pickCurrency(tester, 'JPY');
    // JPY has 0 decimal digits: the hero drops the fractional part.
    expect(find.text('JPY'), findsWidgets);
    expect(find.text('3,000'), findsOneWidget);
    expect(find.text('3,000.00'), findsNothing);
  });

  testWidgets(
    'editing a converted expense opens on its frozen currency and rate',
    (tester) async {
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: convertedExpense(), // JPY / 0.0058 / 2026-08-16, amount 17.40
      );
      expect(_entryCurrencyLabel('JPY'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
            .controller!
            .text,
        '0.0058',
      );
      // The amount field is seeded from the ORIGINAL amount, not the ledger one.
      expect(find.text('3,000'), findsOneWidget);
      expect(find.text('17.40'), findsNothing);
    },
  );

  testWidgets('a remembered rate prefills the next expense in that currency', (
    tester,
  ) async {
    // A stored blob, as a previous save would have left it.
    _prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
    await pumpEditor(tester, currencyCode: 'EUR');
    await _pickCurrency(tester, 'CHF');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
          .controller!
          .text,
      '0.9432',
    );
  });

  testWidgets(
    'the remembered rate is per currency — switching currency does not carry it',
    (tester) async {
      _prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
      await pumpEditor(tester, currencyCode: 'EUR');
      await _pickCurrency(tester, 'CHF');
      await _pickCurrency(tester, 'JPY');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
            .controller!
            .text,
        '',
      );
    },
  );

  testWidgets('Reset clears the remembered rate and empties the field', (
    tester,
  ) async {
    _prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
    await pumpEditor(tester, currencyCode: 'EUR');
    await _pickCurrency(tester, 'CHF');
    await tester.tap(find.byKey(const ValueKey('expense_rate_reset')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
          .controller!
          .text,
      '',
    );
    expect(
      jsonDecode(_prefs.values[kStickyRatesPrefKey]!),
      <String, dynamic>{},
    );
    expect(find.byKey(const ValueKey('expense_rate_reset')), findsNothing);
  });

  testWidgets(
    'switching back to the group currency re-converts the amount at the frozen rate',
    (tester) async {
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: convertedExpense(), // JPY 3000 @ 0.0058 -> 17.40 EUR
      );
      expect(find.text('3,000'), findsOneWidget);

      await _pickCurrency(tester, 'EUR');

      // The value the ledger already holds is preserved — not 3000 EUR, and
      // not a cleared field.
      expect(find.text('17.40'), findsOneWidget);
      expect(find.text('3,000'), findsNothing);
      expect(_entryCurrencyLabel('EUR'), findsOneWidget);
    },
  );

  testWidgets('switching back clears the rate field and the rate row', (
    tester,
  ) async {
    await pumpEditor(tester, currencyCode: 'EUR', expense: convertedExpense());
    await _pickCurrency(tester, 'EUR');
    expect(find.byKey(const ValueKey('expense_rate_field')), findsNothing);
    expect(find.byKey(const ValueKey('expense_rate_preview')), findsNothing);
  });

  testWidgets(
    'switching to a foreign currency and straight back leaves the typed amount alone',
    (tester) async {
      await pumpEditor(tester, currencyCode: 'EUR', initialAmount: 12.5);
      await _pickCurrency(tester, 'CHF'); // no rate typed
      await _pickCurrency(tester, 'EUR');
      expect(find.text('12.50'), findsOneWidget);
    },
  );

  testWidgets(
    'the preview converts each line, so 3 x 1.50 CHF at 0.9432 shows 4.23',
    (tester) async {
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: _itemizedExpense(const [1.50, 1.50, 1.50]),
      );
      await _pickCurrency(tester, 'CHF');
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '0.9432',
      );
      await tester.pumpAndSettle();

      // The save converts each entry on its own (1.41 x3). Converting the
      // summed 4.50 once would preview 4.24 — a cent the ledger never stores.
      expect(find.textContaining('EUR 4.23'), findsOneWidget);
      expect(find.textContaining('EUR 4.24'), findsNothing);
    },
  );

  testWidgets(
    'switching a qty-3 line back keeps its 28.30 ledger total, not 28.29',
    (tester) async {
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: convertedClaimExpense(), // CHF 10.00 x3 @ 0.9432 -> 28.30 EUR
      );
      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.fields['expense_entry[0][quantity]']?.value, '3');

      await _pickCurrency(tester, 'EUR');

      // What the save reads back: unit price x quantity, rounded. Re-converting
      // the UNIT price would have written 9.43 here and stored 28.29.
      final amount = form.fields['expense_entry[0][amount]']!.value;
      expect(
        roundCurrency(double.parse(amount.toString()) * 3, Currency.eur),
        28.30,
      );
      // The quantity survives the switch — the units are still claimable.
      expect(form.fields['expense_entry[0][quantity]']?.value, '3');
      expect(_entryCurrencyLabel('EUR'), findsOneWidget);
    },
  );

  testWidgets(
    'switching back re-renders the item row, not just the header and the save',
    (tester) async {
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: convertedClaimExpense(), // CHF 10.00 x3 @ 0.9432 -> 28.30 EUR
      );
      // Before: the row reads "CHF 10.00 each" with a CHF 30.00 line total.
      expect(find.text('10.00'), findsOneWidget);

      await _pickCurrency(tester, 'EUR');

      // After: the row must show the same figure the header and the save use.
      // The item widget keeps its ValueKey(index) across the switch, so this is
      // exactly the resync that was missing.
      expect(find.text('10.00'), findsNothing);
      expect(find.text('9.43'), findsOneWidget);
      expect(find.textContaining('28.30'), findsWidgets);
      expect(find.textContaining('30.00'), findsNothing);
    },
  );

  testWidgets(
    'an exact-split converted expense opens on the ENTERED shares, not the ledger ones',
    (tester) async {
      // 2.25 CHF a head, stored as 2.12 EUR. Seeding the exact fields from
      // fixed_amount would show 2.12 and re-convert it on the next save.
      await pumpEditor(
        tester,
        currencyCode: 'EUR',
        expense: convertedExactExpense(),
      );
      expect(find.text('2.25'), findsNWidgets(2));
      expect(find.text('2.12'), findsNothing);
    },
  );

  testWidgets(
    'saving that exact split back reproduces its ledger values byte-identically',
    (tester) async {
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedExactExpense(),
      );
      await _save(tester);

      expect(saved, hasLength(1));
      final conversion = saved.single.conversion!;
      final shareData =
          saved.single.formValue['expense_entry[0][share_data]']
              as Map<String, dynamic>;
      // Entry-currency in, entry-currency out.
      expect(shareData.values.map((v) => (v as num).toDouble()).toList(), [
        2.25,
        2.25,
      ]);
      // ...and converting them once lands on exactly the stored ledger values.
      expect(conversion.toLedger(2.25), 2.12);
      expect(conversion.toLedger(saved.single.enteredAmount(0)), 4.24);
      // The percentages the repository derives stay currency-clean: entered
      // share over entered total, 50% a head rather than 47%.
      final entered = saved.single.enteredAmount(0);
      for (final value in shareData.values) {
        expect(((value as num).toDouble() / entered) * 100, closeTo(50, 1e-9));
      }
    },
  );

  testWidgets(
    'a name-only edit leaves the stored rate, rate date and converted amount untouched',
    (tester) async {
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedExpense(), // JPY 3000 @ 0.0058 -> 17.40 EUR
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.expenseDescriptionHint),
        'Kiosk am Bahnhof',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved, hasLength(1));
      final payload = saved.single;
      expect(payload.formValue['name'], 'Kiosk am Bahnhof');
      // Nothing about the money moved: the entry currency, the frozen rate and
      // the date it is attributed to are the ones the expense was loaded with,
      // and the amount the ledger receives is the one it already holds.
      expect(payload.currency, Currency.eur);
      expect(payload.conversion!.entryCurrency, Currency.jpy);
      expect(payload.conversion!.expenseProvenance, {
        'original_currency_code': 'JPY',
        'conversion_rate': 0.0058,
        'rate_date': '2026-08-16',
      });
      expect(payload.enteredAmount(0), 3000);
      expect(payload.conversion!.toLedger(3000), 17.40);
    },
  );

  testWidgets(
    'a CHF -> EUR -> CHF round trip on a DIFFERENT rate re-dates it',
    (tester) async {
      // The sticky rate a later expense left behind is not the rate the
      // expense was frozen at, so it must not be filed under the frozen date.
      _prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.95});
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedChfExpense(), // CHF 100 @ 0.9432, dated 2026-08-16
      );
      await _pickCurrency(tester, 'EUR');
      await _pickCurrency(tester, 'CHF');
      await _save(tester);

      expect(saved, hasLength(1));
      expect(saved.single.conversion!.rate, 0.95);
      expect(saved.single.conversion!.rateDate, isNot('2026-08-16'));
      expect(saved.single.conversion!.rateDate, ymd(DateTime.now()));
    },
  );

  testWidgets(
    'the same round trip landing back on the FROZEN rate keeps its date',
    (tester) async {
      // Same rate, so the date is still a true fact about it — the freeze must
      // survive, which is what stops the gate from being a blanket re-stamp.
      _prefs.values[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedChfExpense(),
      );
      await _pickCurrency(tester, 'EUR');
      await _pickCurrency(tester, 'CHF');
      await _save(tester);

      expect(saved.single.conversion!.rate, 0.9432);
      expect(saved.single.conversion!.rateDate, '2026-08-16');
    },
  );
}
