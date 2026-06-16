import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';

/// Resolves the light and dark [TextTheme]s produced by [getThemeData] inside a
/// real widget tree (GoogleFonts needs a binding).
Future<({TextTheme light, TextTheme dark})> _resolveTextThemes(WidgetTester tester) async {
  late TextTheme light;
  late TextTheme dark;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          light = getThemeData(context, kBrandSeed, Brightness.light).textTheme;
          dark = getThemeData(context, kBrandSeed, Brightness.dark).textTheme;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return (light: light, dark: dark);
}

void main() {
  group('getThemeData textTheme typography', () {
    testWidgets('headings use Bricolage Grotesque', (tester) async {
      final themes = await _resolveTextThemes(tester);
      final t = themes.light;

      expect(t.displayLarge!.fontFamily, contains('Bricolage'));
      expect(t.displayMedium!.fontFamily, contains('Bricolage'));
      expect(t.displaySmall!.fontFamily, contains('Bricolage'));
      expect(t.headlineLarge!.fontFamily, contains('Bricolage'));
      expect(t.headlineMedium!.fontFamily, contains('Bricolage'));
      expect(t.headlineSmall!.fontFamily, contains('Bricolage'));
      expect(t.titleLarge!.fontFamily, contains('Bricolage'));
    });

    testWidgets('body, titles and labels use Hanken Grotesk', (tester) async {
      final themes = await _resolveTextThemes(tester);
      final t = themes.light;

      expect(t.titleMedium!.fontFamily, contains('Hanken'));
      expect(t.titleSmall!.fontFamily, contains('Hanken'));
      expect(t.bodyLarge!.fontFamily, contains('Hanken'));
      expect(t.bodyMedium!.fontFamily, contains('Hanken'));
      expect(t.bodySmall!.fontFamily, contains('Hanken'));
      expect(t.labelLarge!.fontFamily, contains('Hanken'));
      expect(t.labelMedium!.fontFamily, contains('Hanken'));
      expect(t.labelSmall!.fontFamily, contains('Hanken'));
    });

    testWidgets('display and headline styles carry tabular figures', (tester) async {
      final themes = await _resolveTextThemes(tester);
      final t = themes.light;
      const tabular = FontFeature.tabularFigures();

      expect(t.displayLarge!.fontFeatures, contains(tabular));
      expect(t.displayMedium!.fontFeatures, contains(tabular));
      expect(t.displaySmall!.fontFeatures, contains(tabular));
      expect(t.headlineLarge!.fontFeatures, contains(tabular));
      expect(t.headlineMedium!.fontFeatures, contains(tabular));
      expect(t.headlineSmall!.fontFeatures, contains(tabular));
    });

    testWidgets('Bricolage display styles have negative (tightened) letter spacing', (tester) async {
      final themes = await _resolveTextThemes(tester);
      final t = themes.light;

      expect(t.displayLarge!.letterSpacing, isNotNull);
      expect(t.displayLarge!.letterSpacing, lessThan(0));
      expect(t.headlineMedium!.letterSpacing, lessThan(0));
      expect(t.titleLarge!.letterSpacing, lessThan(0));
    });

    testWidgets('dark text theme matches the same families', (tester) async {
      final themes = await _resolveTextThemes(tester);
      final t = themes.dark;

      expect(t.displayLarge!.fontFamily, contains('Bricolage'));
      expect(t.bodyLarge!.fontFamily, contains('Hanken'));
      expect(t.labelMedium!.fontFamily, contains('Hanken'));
    });
  });
}
