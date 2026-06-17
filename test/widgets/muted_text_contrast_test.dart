import 'dart:math' as math;

import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance of an sRGB [color] (alpha ignored — colors are
/// assumed opaque tokens).
double _relativeLuminance(Color color) {
  double channel(double c) {
    final s = c; // already 0..1 in the wide-gamut Color API
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colors (1..21).
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// AA threshold for normal body text.
const double _aaBody = 4.5;

/// Resolves the redesign [ColorScheme] for a [brightness] by pumping a builder
/// so [getThemeData] has a real [BuildContext] for its ambient theme reads.
Future<ColorScheme> _resolveScheme(
  WidgetTester tester,
  Brightness brightness,
) async {
  late ColorScheme scheme;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          scheme = getThemeData(context, kBrandSeed, brightness).colorScheme;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return scheme;
}

void main() {
  group('Muted text (onSurfaceVariant) WCAG AA contrast', () {
    testWidgets('passes AA on all surfaces in light mode', (tester) async {
      final cs = await _resolveScheme(tester, Brightness.light);
      final muted = cs.onSurfaceVariant;
      final surfaces = <String, Color>{
        'surface': cs.surface,
        'surfaceBright': cs.surfaceBright,
        'surfaceContainerLowest': cs.surfaceContainerLowest,
        'surfaceContainerLow': cs.surfaceContainerLow,
        'surfaceContainer': cs.surfaceContainer,
        'surfaceContainerHigh': cs.surfaceContainerHigh,
        'surfaceContainerHighest': cs.surfaceContainerHighest,
      };
      surfaces.forEach((name, bg) {
        expect(
          _contrast(muted, bg),
          greaterThanOrEqualTo(_aaBody),
          reason: 'light muted text on $name must meet AA',
        );
      });
    });

    testWidgets('passes AA on all surfaces in dark mode', (tester) async {
      final cs = await _resolveScheme(tester, Brightness.dark);
      final muted = cs.onSurfaceVariant;
      final surfaces = <String, Color>{
        'surface': cs.surface,
        'surfaceBright': cs.surfaceBright,
        'surfaceContainerLowest': cs.surfaceContainerLowest,
        'surfaceContainerLow': cs.surfaceContainerLow,
        'surfaceContainer': cs.surfaceContainer,
        'surfaceContainerHigh': cs.surfaceContainerHigh,
        // The BalancePill settled state renders muted text on this surface.
        'surfaceContainerHighest': cs.surfaceContainerHighest,
      };
      surfaces.forEach((name, bg) {
        expect(
          _contrast(muted, bg),
          greaterThanOrEqualTo(_aaBody),
          reason: 'dark muted text on $name must meet AA',
        );
      });
    });
  });
}
