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
        kSupportedCurrencies.map((c) => c.code),
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
    test('USD renders "USD 1,234.56" in en', () {
      expect(en.toCurrency(1234.56, 'USD'), 'USD 1,234.56');
    });

    test('de keeps the code in front and changes only the separators', () {
      // Symbol placement used to flip per locale ("1.234,56 €"); the ISO code
      // never does, so the reading order is the same in every locale.
      expect(de.toCurrency(1234.56, 'EUR'), 'EUR 1.234,56');
    });

    test(
      'the code differs by currency within the same locale (USD vs EUR)',
      () {
        expect(en.toCurrency(1234.56, 'USD'), startsWith('USD '));
        expect(en.toCurrency(1234.56, 'EUR'), startsWith('EUR '));
        expect(
          en.toCurrency(1234.56, 'USD'),
          isNot(en.toCurrency(1234.56, 'EUR')),
        );
      },
    );

    test(
      'relabel-not-convert: same amount, same digits, only the code changes',
      () {
        // Changing a group's currency relabels amounts without converting values.
        expect(en.toCurrency(1234.56, 'USD'), contains('1,234.56'));
        expect(en.toCurrency(1234.56, 'GBP'), contains('1,234.56'));
      },
    );

    test('no amount carries a currency symbol at all', () {
      expect(en.toCurrency(5), en.toCurrency(5, 'EUR'));
      for (final code in const ['EUR', 'USD', 'GBP', 'JPY', 'CHF']) {
        final s = en.toCurrency(5, code);
        expect(RegExp(r'[^\x00-\x7F]').hasMatch(s), isFalse, reason: s);
        expect(s, isNot(contains(r'$')));
      }
    });
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
      'a USD group and an EUR group show their own codes side by side',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const Row(
              children: [
                MoneyText(1234.56, currency: Currency.usd),
                MoneyText(1234.56, currency: Currency.eur),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('USD 1,234.56'), findsOneWidget);
        expect(find.text('EUR 1,234.56'), findsOneWidget);
      },
    );

    testWidgets('MoneyText defaults to EUR when no currency is given', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const MoneyText(1234.56)));
      await tester.pump();
      expect(find.text('EUR 1,234.56'), findsOneWidget);
    });
  });
}
