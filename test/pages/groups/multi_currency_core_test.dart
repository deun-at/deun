import 'dart:convert';
import 'dart:io';

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/currency_scope.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const en = Locale('en');
  const de = Locale('de');

  group('formatMoney is currency- and locale-aware', () {
    // German currency formatting places a NO-BREAK SPACE (U+00A0), not a
    // plain space, between the amount and a trailing symbol — standard `intl`
    // German locale data.
    test('JPY renders "¥3,000" in en and "3.000 ¥" in de', () {
      expect(formatMoney(3000, Currency.jpy, en), '¥3,000');
      expect(formatMoney(3000, Currency.jpy, de), '3.000 ¥');
    });

    test('USD renders "\$1,234.56" in en and "1.234,56 \$" in de', () {
      expect(formatMoney(1234.56, Currency.usd, en), r'$1,234.56');
      expect(formatMoney(1234.56, Currency.usd, de), '1.234,56 \$');
    });

    test('EUR is unchanged in both locales', () {
      expect(formatMoney(1234.56, Currency.eur, en), '€1,234.56');
      expect(formatMoney(1234.56, Currency.eur, de), '1.234,56 €');
    });

    test('formatMoneyQualified leads with the ISO code, never the symbol', () {
      expect(formatMoneyQualified(4.50, Currency.chf, en), 'CHF 4.50');
      expect(formatMoneyQualified(3000, Currency.jpy, en), 'JPY 3,000');
    });

    test(
      'formatMoneyQualified never repeats a code that is its own symbol',
      () {
        // "CHF CHF4.50" is the shape this exists to make impossible — and the
        // seven currencies sharing "$" are the reason a symbol cannot identify
        // a currency on its own.
        for (final c in kSupportedCurrencies) {
          final s = formatMoneyQualified(1, c, en);
          expect(
            c.code.allMatches(s).length,
            1,
            reason: '${c.code} rendered "$s"',
          );
          expect(s.startsWith('${c.code} '), isTrue, reason: s);
        }
      },
    );

    test('formatMoneyQualified keeps the currency\'s own decimal digits', () {
      expect(formatMoneyQualified(1234.56, Currency.jpy, en), 'JPY 1,235');
    });

    test('no 0-decimal currency ever renders a fractional part', () {
      for (final c in kSupportedCurrencies.where((c) => c.decimalDigits == 0)) {
        for (final l in const [en, de]) {
          final s = formatMoney(1234.56, c, l);
          expect(
            RegExp(r'[.,]\d\d(?!\d)').hasMatch(s),
            isFalse,
            reason: '${c.code} in $l rendered "$s"',
          );
        }
      }
    });
  });

  group('formatAmountOnly renders the bare number in the locale', () {
    test('12.5 in EUR is "12.50" in en and "12,50" in de', () {
      expect(formatAmountOnly(12.5, Currency.eur, en), '12.50');
      expect(formatAmountOnly(12.5, Currency.eur, de), '12,50');
    });

    test('3000 in JPY carries no fractional part', () {
      expect(formatAmountOnly(3000, Currency.jpy, en), '3,000');
      expect(formatAmountOnly(3000, Currency.jpy, de), '3.000');
    });
  });

  group('AppLocalizations.toCurrency routes through the currency', () {
    late AppLocalizations enL10n;
    late AppLocalizations deL10n;

    setUpAll(() async {
      enL10n = await AppLocalizations.delegate.load(en);
      deL10n = await AppLocalizations.delegate.load(de);
    });

    test('a 0-decimal code loses its fractional digits', () {
      expect(enL10n.toCurrency(3000, 'JPY'), '¥3,000');
      expect(deL10n.toCurrency(3000, 'JPY'), '3.000 ¥');
    });

    test('an unknown code falls back to EUR instead of throwing', () {
      expect(enL10n.toCurrency(5, 'XXX'), enL10n.toCurrency(5, 'EUR'));
    });

    test('2-decimal formatting is unchanged', () {
      expect(enL10n.toCurrency(1234.56, 'USD'), r'$1,234.56');
      expect(deL10n.toCurrency(1234.56, 'EUR'), '1.234,56 €');
    });
  });

  group('dead l10n keys', () {
    Map<String, dynamic> arb(String p) =>
        jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

    test(
      'groupDisplayAmount and groupDisplaySumAmount are gone from both ARBs',
      () {
        final enArb = arb('lib/l10n/app_en.arb');
        final deArb = arb('lib/l10n/app_de.arb');
        for (final key in const [
          'groupDisplayAmount',
          'groupDisplaySumAmount',
        ]) {
          expect(
            enArb.containsKey(key),
            isFalse,
            reason: '$key still in app_en.arb',
          );
          expect(
            enArb.containsKey('@$key'),
            isFalse,
            reason: '@$key still in app_en.arb',
          );
          expect(
            deArb.containsKey(key),
            isFalse,
            reason: '$key still in app_de.arb',
          );
        }
      },
    );
  });

  test('no user-visible amount renders a hardcoded € (regression guard)', () {
    // Legitimate occurrences: the EUR registry entry, and the receipt OCR regex
    // that *parses* a euro sign out of scanned text. Everything else must be a
    // comment.
    const allowed = {
      'lib/helper/currency.dart',
      'lib/pages/expenses/service/receipt_parser.dart',
    };
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (allowed.any(rel.endsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('€')) offenders.add('$rel:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty);
  });

  group('CurrencyScope + MoneyText', () {
    Widget harness(Widget child, {Locale locale = const Locale('en')}) =>
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeBuilder(
            colorValue: 0xFF000000,
            builder: (context) => Scaffold(body: child),
          ),
        );

    testWidgets('an explicit currency wins over the scope', (tester) async {
      await tester.pumpWidget(
        harness(
          const CurrencyScope(
            currency: Currency.eur,
            child: MoneyText(1234.56, currency: Currency.usd),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(r'$1,234.56'), findsOneWidget);
    });

    testWidgets('an omitted currency falls back to the scope', (tester) async {
      await tester.pumpWidget(
        harness(
          const CurrencyScope(currency: Currency.jpy, child: MoneyText(3000)),
        ),
      );
      await tester.pump();
      expect(find.text('¥3,000'), findsOneWidget);
    });

    testWidgets('with no scope mounted it falls back to EUR, not a throw', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const MoneyText(1234.56)));
      await tester.pump();
      expect(find.text('€1,234.56'), findsOneWidget);
    });

    testWidgets('a 0-decimal currency renders no fractional part', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const MoneyText(2500.6, currency: Currency.jpy)),
      );
      await tester.pump();
      expect(find.text('¥2,501'), findsOneWidget);
    });

    testWidgets('the German locale places the symbol after the amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const MoneyText(3000, currency: Currency.jpy),
          locale: const Locale('de'),
        ),
      );
      await tester.pump();
      expect(find.text('3.000 ¥'), findsOneWidget);
    });

    testWidgets('a USD group and an EUR group show their own symbols', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const Row(
            children: [
              MoneyText(1234.56, currency: Currency.usd),
              MoneyText(1234.56, currency: Currency.eur),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text(r'$1,234.56'), findsOneWidget);
      expect(find.text('€1,234.56'), findsOneWidget);
    });
  });
}
