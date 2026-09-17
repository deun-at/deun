// The card fee entry sheet, which Settings and the conversion sheet both
// write through. The Settings ROW that opens it is covered by
// setting_page_test.dart.
//
// The regression this file exists for: a typo in the fee field must never
// silently delete a saved fee. Reachable in `de`, where the field is seeded
// "1,4" and DecimalTextInputFormatter accepts a trailing separator ("1,4.")
// that double.tryParse then rejects.

import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/card_fee_sheet.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the async_preferences platform channel.
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

late _FakePrefs _prefs;

/// Pumps a bare host that opens the fee sheet, in [locale].
Future<ProviderContainer> _pumpSheet(
  WidgetTester tester, {
  double? initial,
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CardFeeSheet(initial: initial)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('card_fee_save')));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('card_fee_field')))
    .controller!
    .text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _prefs = _FakePrefs()..install();
  });

  testWidgets('a typed fee is stored', (tester) async {
    final container = await _pumpSheet(tester);
    await tester.enterText(find.byKey(const ValueKey('card_fee_field')), '1.4');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(container.read(cardFeeProvider), 1.4);
    expect(_prefs.values[kCardFeePrefKey], '1.4');
  });

  testWidgets(
    'an EMPTY field clears the fee — blank is the way to say "none"',
    (tester) async {
      _prefs.values[kCardFeePrefKey] = '1.4';
      final container = await _pumpSheet(tester, initial: 1.4);
      await tester.enterText(find.byKey(const ValueKey('card_fee_field')), '');
      await tester.pumpAndSettle();
      await _tapSave(tester);

      expect(container.read(cardFeeProvider), isNull);
      expect(_prefs.values.containsKey(kCardFeePrefKey), isFalse);
    },
  );

  // The regression. "1,4." passes the input formatter (isDoubleDot counts only
  // '.', and "1,4." splits into two parts) but double.tryParse refuses it.
  testWidgets('a typo never deletes the saved fee — it is reported instead', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));
    _prefs.values[kCardFeePrefKey] = '1.4';
    final container = await _pumpSheet(
      tester,
      initial: 1.4,
      locale: const Locale('de'),
    );
    // The seeded German text, plus the trailing separator that slips through.
    expect(_fieldText(tester), '1,4');
    await tester.enterText(
      find.byKey(const ValueKey('card_fee_field')),
      '1,4.',
    );
    await tester.pumpAndSettle();
    await _tapSave(tester);

    // Still stored, still on screen, and the user is told why.
    expect(_prefs.values[kCardFeePrefKey], '1.4');
    await container.read(cardFeeProvider.notifier).hydrated;
    expect(container.read(cardFeeProvider.notifier).cardFeePercent, 1.4);
    expect(find.byType(CardFeeSheet), findsOneWidget);
    expect(find.text(l10n.cardFeeSheetInvalid), findsOneWidget);
  });

  // `de`, because that is the only locale the invalid text is reachable in:
  // in `en` the formatter rejects "1.4." itself (isDoubleDot sees three
  // parts), so Save never sees it.
  testWidgets('the error clears on the next keystroke', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));
    await _pumpSheet(tester, locale: const Locale('de'));
    await tester.enterText(
      find.byKey(const ValueKey('card_fee_field')),
      '1,4.',
    );
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text(l10n.cardFeeSheetInvalid), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('card_fee_field')), '1,4');
    await tester.pumpAndSettle();
    expect(find.text(l10n.cardFeeSheetInvalid), findsNothing);
  });

  // One pump per test: re-pumping reuses the State, whose controller is
  // already seeded, so a second locale would never reseed it. That is correct
  // behaviour — reseeding a field mid-edit would discard what the user typed.
  testWidgets('the field seeds the stored fee in en', (tester) async {
    await _pumpSheet(tester, initial: 1.4);
    expect(_fieldText(tester), '1.4');
  });

  testWidgets('the field seeds the stored fee in de, comma-separated', (
    tester,
  ) async {
    await _pumpSheet(tester, initial: 1.4, locale: const Locale('de'));
    expect(_fieldText(tester), '1,4');
  });

  testWidgets('an unset fee seeds an EMPTY field, not a zero', (tester) async {
    await _pumpSheet(tester);
    expect(_fieldText(tester), isEmpty);
  });
}
