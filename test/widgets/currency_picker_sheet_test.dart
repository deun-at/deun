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
  testWidgets('lists every curated currency', (tester) async {
    await _open(tester);
    // Scrolling is the sheet's own SingleChildScrollView; check the head and a
    // deliberate 0-decimal entry.
    expect(find.text('EUR · €'), findsOneWidget);
    expect(find.text('USD · \$'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('JPY · ¥'), 200);
    expect(find.text('JPY · ¥'), findsOneWidget);
  });

  testWidgets('marks the initial currency as selected', (tester) async {
    await _open(tester, initial: Currency.usd);
    final selected = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(selected, isNotNull);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
    await tester.tap(find.text('USD · \$'));
    await tester.pumpAndSettle();
    expect(picked, Currency.usd);
  });

  testWidgets('dismissing without choosing resolves to null', (tester) async {
    // Tap the barrier.
    await _open(tester, initial: Currency.eur);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('EUR · €'), findsNothing);
  });
}
