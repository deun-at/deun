import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/expenses/presentation/receipt_scanner_sheet.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptScanResult _result({
  String? merchant = 'Cafe Central',
  List<ReceiptLineItem>? items,
  double? total,
}) {
  return ReceiptScanResult(
    merchantName: merchant,
    lineItems: items ??
        const [
          ReceiptLineItem(name: 'Coffee', amount: 4.50),
          ReceiptLineItem(name: 'Croissant', amount: 3.20),
        ],
    total: total,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
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
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, brightness)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('receiptPreviewTotal', () {
    test('uses the parsed total when present', () {
      final r = _result(total: 9.99);
      expect(receiptPreviewTotal(r), 9.99);
    });

    test('falls back to the sum of line items when no total', () {
      final r = _result(total: null);
      expect(receiptPreviewTotal(r), closeTo(7.70, 1e-9));
    });

    test('is zero for an empty result', () {
      const r = ReceiptScanResult();
      expect(receiptPreviewTotal(r), 0);
    });
  });

  group('ReceiptItemsPreview', () {
    testWidgets('lists each detected item with its amount', (tester) async {
      await _pump(
        tester,
        ReceiptItemsPreview(
          result: _result(),
          onConfirm: () {},
          onRetake: () {},
        ),
      );

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Croissant'), findsOneWidget);
      // Each row renders its price via MoneyText.
      expect(find.byType(MoneyText), findsWidgets);
    });

    testWidgets('shows the merchant name when present', (tester) async {
      await _pump(
        tester,
        ReceiptItemsPreview(
          result: _result(merchant: 'Cafe Central'),
          onConfirm: () {},
          onRetake: () {},
        ),
      );
      expect(find.text('Cafe Central'), findsOneWidget);
    });

    testWidgets('uses v3 button presets (not raw Material buttons)',
        (tester) async {
      await _pump(
        tester,
        ReceiptItemsPreview(
          result: _result(),
          onConfirm: () {},
          onRetake: () {},
        ),
      );

      // Confirm is the PrimaryButton preset; retake is the SecondaryButton
      // preset — no stock Material buttons should remain in the footer.
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('confirm invokes onConfirm', (tester) async {
      var confirmed = false;
      await _pump(
        tester,
        ReceiptItemsPreview(
          result: _result(),
          onConfirm: () => confirmed = true,
          onRetake: () {},
        ),
      );

      await tester.tap(find.byKey(const ValueKey('receipt_confirm')));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pump(
        tester,
        ReceiptItemsPreview(
          result: _result(),
          onConfirm: () {},
          onRetake: () {},
        ),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ReceiptScannerSheet', () {
    testWidgets('idle state shows the instructions and capture actions',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, const ReceiptScannerSheet());

      expect(find.byType(SheetScaffold), findsOneWidget);
      expect(find.text(l10n.receiptScanInstructions), findsOneWidget);
      expect(find.text(l10n.receiptScanTakePhoto), findsOneWidget);
      expect(find.text(l10n.receiptScanChooseGallery), findsOneWidget);
      // Capture actions use the v3 presets, not raw Material buttons.
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
