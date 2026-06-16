import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';

/// Builds the theme inside a real widget tree (getThemeData reads inherited
/// theme data via Theme.of) and returns its [SemanticColors] extension.
Future<SemanticColors> _semanticColors(WidgetTester tester, Brightness brightness) async {
  late SemanticColors colors;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          colors = getThemeData(context, kBrandSeed, brightness).extension<SemanticColors>()!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return colors;
}

void main() {
  group('SemanticColors theme extension', () {
    testWidgets('light variant uses the spec light semantic hues', (tester) async {
      final colors = await _semanticColors(tester, Brightness.light);
      expect(colors.success, const Color(0xFF1A8F5E));
      expect(colors.danger, const Color(0xFFD85A47));
      expect(colors.warning, const Color(0xFFC98A2E));
    });

    testWidgets('dark variant uses the on-dark semantic variants', (tester) async {
      final colors = await _semanticColors(tester, Brightness.dark);
      expect(colors.success, const Color(0xFF4ED99B));
      expect(colors.danger, const Color(0xFFF2937F));
      expect(colors.warning, const Color(0xFFF2C97F));
    });

    testWidgets('payback chip pair differs between light and dark', (tester) async {
      final light = await _semanticColors(tester, Brightness.light);
      final dark = await _semanticColors(tester, Brightness.dark);
      expect(light.paybackBackground, const Color(0xFFEAF6EF));
      expect(light.paybackText, const Color(0xFF2F7A55));
      expect(dark.paybackBackground, isNot(light.paybackBackground));
      expect(dark.paybackText, isNot(light.paybackText));
    });

    testWidgets('a sample owed/owe label resolves via Theme.of and flips in dark', (tester) async {
      // Exercises the acceptance criterion: a real widget reads the semantic
      // colors from the theme (never a hard-coded hex) and gets the on-dark
      // variants under a dark theme.
      Future<(Color owed, Color owe)> labelColors(Brightness brightness) async {
        late Color owed;
        late Color owe;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (outer) {
                // Apply the redesign theme the same way ThemeBuilder does.
                return Theme(
                  data: getThemeData(outer, kBrandSeed, brightness),
                  child: Builder(
                    builder: (context) {
                      final semantic = Theme.of(context).extension<SemanticColors>()!;
                      owed = semantic.success;
                      owe = semantic.danger;
                      return Column(
                        children: [
                          Text('owed', style: TextStyle(color: owed)),
                          Text('owe', style: TextStyle(color: owe)),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        return (owed, owe);
      }

      final (lightOwed, lightOwe) = await labelColors(Brightness.light);
      expect(lightOwed, const Color(0xFF1A8F5E));
      expect(lightOwe, const Color(0xFFD85A47));

      final (darkOwed, darkOwe) = await labelColors(Brightness.dark);
      expect(darkOwed, const Color(0xFF4ED99B));
      expect(darkOwe, const Color(0xFFF2937F));
    });

    test('copyWith overrides only the given field', () {
      const base = SemanticColors.light;
      final copy = base.copyWith(success: const Color(0xFF000000));
      expect(copy.success, const Color(0xFF000000));
      expect(copy.danger, base.danger);
      expect(copy.warning, base.warning);
    });

    test('lerp toward the other instance lands on it at t=1', () {
      const light = SemanticColors.light;
      const dark = SemanticColors.dark;
      final mid = light.lerp(dark, 1.0);
      expect(mid.success, dark.success);
    });
  });

  group('memberAvatarColor', () {
    test('is stable for the same key', () {
      expect(memberAvatarColor('a@x.com'), memberAvatarColor('a@x.com'));
    });

    test('returns a color from the avatar palette', () {
      expect(kMemberAvatarPalette, contains(memberAvatarColor('a@x.com')));
    });

    test('different keys can map to different colors', () {
      final colors = <Color>{
        for (var i = 0; i < 50; i++) memberAvatarColor('user$i@example.com'),
      };
      expect(colors.length, greaterThan(1));
    });

    test('palette holds the ten spec avatar colors', () {
      expect(kMemberAvatarPalette.length, 10);
      expect(kMemberAvatarPalette, contains(const Color(0xFF5750E6)));
    });
  });

  group('kGroupColorPalette', () {
    test('has the six spec swatches', () {
      expect(kGroupColorPalette.length, 6);
    });

    test('includes the brand indigo', () {
      expect(kGroupColorPalette, contains(const Color(0xFF5750E6)));
    });
  });
}
