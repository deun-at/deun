import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceptance tests for multi-currency-foundation. Every assertion restates an
/// acceptance criterion from the plan.
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

  Map<String, dynamic> _groupJson({String? currencyCode}) {
    final json = <String, dynamic>{
      'id': 'g1',
      'name': 'Trip',
      'color_value': 0xFF000000,
      'simplified_expenses': false,
      'created_at': '',
      'user_id': null,
      'group_member': const [],
      'group_shares_summary': const [],
    };
    if (currencyCode != null) json['currency_code'] = currencyCode;
    return json;
  }

  group('group currency_code column', () {
    test('existing rows (no currency_code) backfill to EUR', () {
      final g = Group()..loadDataFromJson(_groupJson());
      expect(g.currencyCode, 'EUR');
    });

    test('a row with a null name loads (empty name) instead of throwing', () {
      // Regression: a partially-written row (name=null) must not throw in
      // loadDataFromJson — one bad row would otherwise fail the whole list.
      final json = _groupJson()..['name'] = null;
      final g = Group();
      expect(() => g.loadDataFromJson(json), returnsNormally);
      expect(g.name, '');
    });

    test('a group reads its persisted currency_code', () {
      final g = Group()..loadDataFromJson(_groupJson(currencyCode: 'USD'));
      expect(g.currencyCode, 'USD');
    });

    test('a new Group defaults to EUR', () {
      expect(Group().currencyCode, 'EUR');
      expect(kDefaultCurrencyCode, 'EUR');
    });

    test('currency_code round-trips through toJson', () {
      final g = Group()..loadDataFromJson(_groupJson(currencyCode: 'GBP'));
      expect(g.toJson()['currency_code'], 'GBP');
    });
  });

  group('curated currency list', () {
    test('offers at minimum EUR, USD, GBP, CHF', () {
      expect(
        kSupportedCurrencyCodes,
        containsAll(['EUR', 'USD', 'GBP', 'CHF']),
      );
    });
  });

  group('currency-aware, locale-aware formatting', () {
    late AppLocalizations en;
    late AppLocalizations de;

    setUp(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      de = await AppLocalizations.delegate.load(const Locale('de'));
    });

    test('USD in en-US renders "\$1,234.56"', () {
      expect(en.toCurrency(1234.56, 'USD'), '\$1,234.56');
    });

    test('EUR in de-DE renders symbol after the amount ("1.234,56 €")', () {
      final s = de.toCurrency(1234.56, 'EUR');
      expect(s, contains('1.234,56'));
      expect(s.trimRight().endsWith('€'), isTrue);
    });

    test('symbol differs by currency within the same locale (USD vs EUR)', () {
      expect(en.toCurrency(1234.56, 'USD'), startsWith('\$'));
      expect(en.toCurrency(1234.56, 'EUR'), startsWith('€'));
      expect(
        en.toCurrency(1234.56, 'USD'),
        isNot(en.toCurrency(1234.56, 'EUR')),
      );
    });

    test(
      'relabel-not-convert: same amount, same digits, only the symbol changes',
      () {
        // Changing a group's currency relabels amounts without converting values.
        expect(en.toCurrency(1234.56, 'USD'), contains('1,234.56'));
        expect(en.toCurrency(1234.56, 'GBP'), contains('1,234.56'));
      },
    );

    test(
      'no amount is formatted with a hardcoded € — default code drives the symbol',
      () {
        // The default (EUR) still yields €, but via the currency code path.
        expect(en.toCurrency(5), en.toCurrency(5, 'EUR'));
        expect(en.toCurrency(5, 'USD'), isNot(contains('€')));
      },
    );
  });

  group('MoneyText renders per-group currency', () {
    Widget _harness(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeBuilder(
        colorValue: 0xFF000000,
        builder: (context) => Scaffold(body: child),
      ),
    );

    testWidgets(
      'a USD group and an EUR group show their own symbols side by side',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const Row(
              children: [
                MoneyText(1234.56, currencyCode: 'USD'),
                MoneyText(1234.56, currencyCode: 'EUR'),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('\$1,234.56'), findsOneWidget);
        expect(find.text('€1,234.56'), findsOneWidget);
      },
    );

    testWidgets('MoneyText defaults to the EUR symbol when no code is given', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const MoneyText(1234.56)));
      await tester.pump();
      expect(find.text('€1,234.56'), findsOneWidget);
    });
  });
}
