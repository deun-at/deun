import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/discard_sheet.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a host with a button that opens the discard sheet and records the
/// resolved result, so each test can drive the sheet and then assert.
Future<void> _pumpHost(
  WidgetTester tester,
  List<bool?> sink, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Set the theme at the app level (with NoSplash) so the modal route —
      // pushed into the root navigator overlay — inherits it and avoids the
      // ink-sparkle fragment shader the test engine can't decode.
      theme: ThemeData(brightness: brightness)
          .copyWith(splashFactory: NoSplash.splashFactory),
      builder: (context, child) => Theme(
        data: getThemeData(context, kBrandSeed, brightness)
            .copyWith(splashFactory: NoSplash.splashFactory),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sink.add(await showDiscardConfirmationSheet(context));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows discard title and both actions, Keep editing → false',
      (tester) async {
    final sink = <bool?>[];
    await _pumpHost(tester, sink);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.discardChangesTitle), findsOneWidget);
    expect(find.text(l10n.discardChangesConfirm), findsOneWidget);
    expect(find.text(l10n.discardChangesKeepEditing), findsOneWidget);

    await tester.tap(find.text(l10n.discardChangesKeepEditing));
    await tester.pumpAndSettle();
    expect(sink, [isFalse]);
  });

  testWidgets('tapping Discard resolves true', (tester) async {
    final sink = <bool?>[];
    await _pumpHost(tester, sink);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.discardChangesConfirm));
    await tester.pumpAndSettle();

    expect(sink.single, isTrue);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    final sink = <bool?>[];
    await _pumpHost(tester, sink, brightness: Brightness.dark);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Dismiss so no modal route stays pending at teardown.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.discardChangesKeepEditing));
    await tester.pumpAndSettle();
  });
}
