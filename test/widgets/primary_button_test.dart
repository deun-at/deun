import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] in the redesign theme at the given [brightness].
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, brightness)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Returns the [BoxDecoration] from the outermost [Container] that carries the
/// button's colored shadow (the one whose [BoxDecoration.boxShadow] is
/// non-null or whose [BoxDecoration.color] equals the primary color).
BoxDecoration? _buttonDecoration(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container)).toList();
  for (final c in containers) {
    final deco = c.decoration;
    if (deco is BoxDecoration && deco.boxShadow != null && deco.boxShadow!.isNotEmpty) {
      return deco;
    }
  }
  return null;
}

void main() {
  group('PrimaryButton', () {
    // -------------------------------------------------------------------------
    // Label + tap
    // -------------------------------------------------------------------------

    testWidgets('renders the label text', (tester) async {
      await _pump(tester, PrimaryButton(label: 'Save', onPressed: () {}));
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped (enabled)', (tester) async {
      var tapped = 0;
      await _pump(tester, PrimaryButton(label: 'Save', onPressed: () => tapped++));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    // -------------------------------------------------------------------------
    // Disabled state
    // -------------------------------------------------------------------------

    testWidgets('onPressed null → tap does nothing', (tester) async {
      var tapped = 0;
      await _pump(tester, const PrimaryButton(label: 'Save', onPressed: null));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, 0);
    });

    testWidgets('disabled → no BoxShadow in container decoration', (tester) async {
      await _pump(tester, const PrimaryButton(label: 'Save', onPressed: null));
      final deco = _buttonDecoration(tester);
      expect(
        deco,
        isNull,
        reason: 'Disabled PrimaryButton must not have a colored BoxShadow',
      );
    });

    // -------------------------------------------------------------------------
    // Enabled light: colored shadow
    // -------------------------------------------------------------------------

    testWidgets('enabled light → container has a BoxShadow with positive y offset', (tester) async {
      await _pump(tester, PrimaryButton(label: 'Save', onPressed: () {}));
      final deco = _buttonDecoration(tester);
      expect(deco, isNotNull, reason: 'Enabled PrimaryButton must have a BoxShadow decoration');
      final shadow = deco!.boxShadow!.first;
      expect(shadow.offset.dy, greaterThan(0),
          reason: 'Shadow y offset must be positive (≈12)');
    });

    testWidgets('enabled light → shadow color is derived from colorScheme.primary', (tester) async {
      late Color primary;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
          home: Builder(builder: (context) {
            final theme = getThemeData(context, kBrandSeed, Brightness.light);
            primary = theme.colorScheme.primary;
            return Theme(
              data: theme.copyWith(splashFactory: NoSplash.splashFactory),
              child: Scaffold(body: Center(child: PrimaryButton(label: 'Go', onPressed: () {}))),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      final deco = _buttonDecoration(tester);
      expect(deco, isNotNull);
      final shadowColor = deco!.boxShadow!.first.color;
      // Shadow must share the same red, green, blue channels as primary.
      expect(shadowColor.r, closeTo(primary.r, 0.01));
      expect(shadowColor.g, closeTo(primary.g, 0.01));
      expect(shadowColor.b, closeTo(primary.b, 0.01));
    });

    // -------------------------------------------------------------------------
    // Full-width default
    // -------------------------------------------------------------------------

    testWidgets('fullWidth:true (default) expands to available width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
          home: Builder(builder: (context) {
            return Theme(
              data: getThemeData(context, kBrandSeed, Brightness.light)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: PrimaryButton(label: 'Go', onPressed: () {}),
                ),
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      final buttonSize = tester.getSize(find.byType(PrimaryButton));
      // On a ~360-wide viewport minus 40 padding = ~320 wide.
      expect(buttonSize.width, greaterThan(200),
          reason: 'fullWidth PrimaryButton must expand horizontally');
    });

    // -------------------------------------------------------------------------
    // Optional icon
    // -------------------------------------------------------------------------

    testWidgets('icon param renders an Icon widget alongside the label', (tester) async {
      await _pump(
        tester,
        PrimaryButton(label: 'Share', onPressed: () {}, icon: Icons.ios_share),
      );
      expect(find.byIcon(Icons.ios_share), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Builds in dark mode
    // -------------------------------------------------------------------------

    testWidgets('builds in dark mode without throwing', (tester) async {
      await _pump(
        tester,
        PrimaryButton(label: 'Save', onPressed: () {}),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('dark mode disabled also builds without throwing', (tester) async {
      await _pump(
        tester,
        const PrimaryButton(label: 'Save', onPressed: null),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Hit target ≥ 48dp
    // -------------------------------------------------------------------------

    testWidgets('hit target height is at least 48dp', (tester) async {
      await _pump(tester, PrimaryButton(label: 'Save', onPressed: () {}));
      final size = tester.getSize(find.byType(PrimaryButton));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: 'Primary CTA must have at least 48dp hit height');
    });

    testWidgets('uses a radius-15 rounded rectangle (not a stadium pill)',
        (tester) async {
      await _pump(tester, PrimaryButton(label: 'Save', onPressed: () {}));
      final deco = _buttonDecoration(tester);
      expect(deco, isNotNull);
      expect(
        deco!.borderRadius,
        BorderRadius.circular(15),
        reason: 'Primary button must be a 15-radius rectangle',
      );
    });
  });

  group('SecondaryButton', () {
    /// Returns the [BoxDecoration] of the secondary button's bordered container.
    BoxDecoration secondaryDecoration(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SecondaryButton),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('renders the label text', (tester) async {
      await _pump(tester, SecondaryButton(label: 'Copy', onPressed: () {}));
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped (enabled)', (tester) async {
      var tapped = 0;
      await _pump(tester, SecondaryButton(label: 'Copy', onPressed: () => tapped++));
      await tester.tap(find.byType(SecondaryButton));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('onPressed null → tap does nothing', (tester) async {
      var tapped = 0;
      await _pump(tester, const SecondaryButton(label: 'Copy', onPressed: null));
      await tester.tap(find.byType(SecondaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, 0);
    });

    testWidgets('is a radius-15 rectangle with a white fill and hairline border',
        (tester) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
          home: Builder(builder: (context) {
            final theme = getThemeData(context, kBrandSeed, Brightness.light);
            scheme = theme.colorScheme;
            return Theme(
              data: theme.copyWith(splashFactory: NoSplash.splashFactory),
              child: Scaffold(
                body: Center(child: SecondaryButton(label: 'Copy', onPressed: () {})),
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      final deco = secondaryDecoration(tester);
      expect(deco.borderRadius, BorderRadius.circular(15),
          reason: 'Secondary button must be a 15-radius rectangle');
      expect(deco.color, scheme.surfaceContainerLowest,
          reason: 'Secondary button fill is the card-white surface');
      final border = deco.border! as Border;
      expect(border.top.width, 1.5,
          reason: 'Secondary button has a 1.5px hairline border');
      expect(border.top.color, scheme.outlineVariant,
          reason: 'Border routes through the outlineVariant hairline token');
    });

    testWidgets('icon param renders an Icon widget alongside the label',
        (tester) async {
      await _pump(
        tester,
        SecondaryButton(label: 'Copy', onPressed: () {}, icon: Icons.copy),
      );
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('label stays single-line (no soft-wrap) so it cannot wrap',
        (tester) async {
      // "Link kopieren" is the DE label that previously wrapped to two lines.
      await _pump(
        tester,
        const SizedBox(
          width: 150,
          child: SecondaryButton(label: 'Link kopieren', onPressed: null, icon: Icons.copy),
        ),
      );
      final text = tester.widget<Text>(find.text('Link kopieren'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    });

    testWidgets('builds in dark mode without throwing', (tester) async {
      await _pump(
        tester,
        SecondaryButton(label: 'Copy', onPressed: () {}),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('hit target height is at least 48dp', (tester) async {
      await _pump(tester, SecondaryButton(label: 'Copy', onPressed: () {}));
      final size = tester.getSize(find.byType(SecondaryButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
