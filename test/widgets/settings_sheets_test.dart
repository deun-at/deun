import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a scaffold with a button that opens [openSheet], then taps it so the
/// sheet is on screen and settled.
Future<void> _openSheet(
  WidgetTester tester,
  void Function(BuildContext) openSheet,
) async {
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
            data: getThemeData(context, kBrandSeed, Brightness.light)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => openSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('language sheet draws no divider between options (F147)',
      (tester) async {
    await _openSheet(
      tester,
      (context) => showLanguageSheet(context, currentTag: null, onSelected: (_) {}),
    );

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('appearance sheet draws no divider between options (F147)',
      (tester) async {
    await _openSheet(tester, (context) => showAppearanceSheet(context));

    expect(find.byType(Divider), findsNothing);
  });
}
