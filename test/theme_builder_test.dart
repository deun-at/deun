import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';

void main() {
  group('getThemeData with kBrandSeed', () {
    testWidgets('light scheme maps the warm-neutral surfaces', (tester) async {
      late ColorScheme scheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              scheme = getThemeData(context, kBrandSeed, Brightness.light).colorScheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(scheme.brightness, Brightness.light);
      expect(scheme.surface, const Color(0xFFF4F3EF));
      expect(scheme.surfaceContainerLowest, const Color(0xFFFFFFFF));
      expect(scheme.surfaceContainerLow, const Color(0xFFFBFAF7));
      expect(scheme.surfaceContainer, const Color(0xFFF1EFE9));
      expect(scheme.surfaceContainerHigh, const Color(0xFFEAE8E1));
      expect(scheme.surfaceContainerHighest, const Color(0xFFF0EEE8));
      expect(scheme.surfaceBright, const Color(0xFFFBFAF7));
      expect(scheme.surfaceDim, const Color(0xFFEAE8E1));
      expect(scheme.onSurface, const Color(0xFF16181A));
      expect(scheme.onSurfaceVariant, const Color(0xFF56524A));
    });

    testWidgets('dark scheme maps the warm near-black surfaces', (tester) async {
      late ColorScheme scheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              scheme = getThemeData(context, kBrandSeed, Brightness.dark).colorScheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, const Color(0xFF121311));
      expect(scheme.surfaceContainerLowest, const Color(0xFF1F211E));
      expect(scheme.surfaceContainerLow, const Color(0xFF1A1B19));
      expect(scheme.surfaceContainer, const Color(0xFF262824));
      expect(scheme.surfaceContainerHigh, const Color(0xFF2E302B));
      expect(scheme.surfaceContainerHighest, const Color(0xFF373B35));
      expect(scheme.surfaceBright, const Color(0xFF262824));
      expect(scheme.surfaceDim, const Color(0xFF121311));
      expect(scheme.onSurface, const Color(0xFFECEBE6));
      expect(scheme.onSurfaceVariant, const Color(0xFF9A968C));
    });

    testWidgets('primary is non-trivially seeded from the brand indigo', (tester) async {
      late ColorScheme light;
      late ColorScheme blueLight;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              light = getThemeData(context, kBrandSeed, Brightness.light).colorScheme;
              blueLight = getThemeData(context, ColorSeed.blue.color, Brightness.light).colorScheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(light.primary, isNot(const Color(0xFF000000)));
      // The brand indigo must produce a different primary than the old blue seed.
      expect(light.primary, isNot(blueLight.primary));
    });

    test('kBrandSeed is the indigo brand color', () {
      expect(kBrandSeed, const Color(0xFF5750E6));
    });
  });
}
