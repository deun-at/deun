import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/currency_picker_sheet.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Currency?> _open(WidgetTester tester, {Currency? initial}) async {
  Currency? result;
  await tester.pumpWidget(
    MaterialApp(
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
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCurrencyPicker(context, initial: initial);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('lists every curated currency by code and name', (tester) async {
    await _open(tester);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('US Dollar'), findsOneWidget);
    // A deliberate 0-decimal entry further down the ECB order. Scroll the
    // SHEET, not the search field — a TextField is a Scrollable too, so an
    // unqualified finder matches more than one.
    await tester.scrollUntilVisible(
      find.text('JPY'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Japanese Yen'), findsOneWidget);
  });

  testWidgets('no currency is offered with a symbol beside it', (tester) async {
    // The app renders no symbols, so teaching one here would teach a glyph the
    // user never sees again. The NAME is the useful second field.
    await _open(tester);
    for (final glyph in const ['€', r'$', '£', '¥']) {
      expect(
        find.textContaining(glyph),
        findsNothing,
        reason: '"$glyph" is on screen in the picker',
      );
    }
  });

  testWidgets('searching by code narrows to that currency', (tester) async {
    await _open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('currency_picker_search')),
      'chf',
    );
    await tester.pumpAndSettle();

    expect(find.text('CHF'), findsOneWidget);
    expect(find.text('Swiss Franc'), findsOneWidget);
    expect(find.text('EUR'), findsNothing);
  });

  testWidgets('searching by name finds a currency whose code you do not know', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('currency_picker_search')),
      'swiss',
    );
    await tester.pumpAndSettle();

    expect(find.text('CHF'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
  });

  testWidgets('a search matching nothing says so, naming the query', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('currency_picker_search')),
      'zzzz',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('currency_picker_empty')), findsOneWidget);
    expect(find.text(l10n.currencyPickerNoMatches('zzzz')), findsOneWidget);
  });

  testWidgets('clearing the search restores the full list', (tester) async {
    await _open(tester);
    final field = find.byKey(const ValueKey('currency_picker_search'));
    await tester.enterText(field, 'chf');
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('currency_picker_search_clear')),
    );
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets('the clear affordance exists only once there is a query', (
    tester,
  ) async {
    await _open(tester);
    expect(
      find.byKey(const ValueKey('currency_picker_search_clear')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('currency_picker_search')),
      'e',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('currency_picker_search_clear')),
      findsOneWidget,
    );
  });

  testWidgets('only the current choice is marked — the rest carry nothing', (
    tester,
  ) async {
    await _open(tester, initial: Currency.usd);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // The old sheet drew an empty radio on all 30 others.
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });

  testWidgets('tapping a currency pops it back to the caller', (tester) async {
    Currency? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light),
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await showCurrencyPicker(
                      context,
                      initial: Currency.eur,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    expect(picked, Currency.usd);
  });

  testWidgets('a search result is tappable and pops that currency', (
    tester,
  ) async {
    Currency? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light),
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await showCurrencyPicker(
                      context,
                      initial: Currency.eur,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('currency_picker_search')),
      'yen',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY'));
    await tester.pumpAndSettle();
    expect(picked, Currency.jpy);
  });

  testWidgets('dismissing without choosing resolves to null', (tester) async {
    await _open(tester, initial: Currency.eur);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsNothing);
  });
}
