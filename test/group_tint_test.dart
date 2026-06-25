import 'package:deun/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupTint — per-group icon tint background (F04)', () {
    // The five canonical group colors and their hand-tuned light tints from
    // DESIGN_SPEC "Group color palette" (+ the #E0735A alternate). These are
    // exact spec tokens, NOT an alpha overlay of the base color.
    const specLightTints = <int, int>{
      0xFF5750E6: 0xFFECEBFC,
      0xFF2F73D9: 0xFFE4EEFB,
      0xFFE0853D: 0xFFFBEEDD,
      0xFFD45A8A: 0xFFFBE7F0,
      0xFFE0735A: 0xFFFBEAE5,
      0xFFB85C9E: 0xFFF6E8F1,
    };

    test('light tint matches the exact spec token for every palette color', () {
      specLightTints.forEach((base, tint) {
        expect(
          groupTint(base, Brightness.light),
          Color(tint),
          reason: 'group color ${base.toRadixString(16)} must use its spec light tint',
        );
      });
    });

    test('every palette swatch has a spec light tint', () {
      for (final c in kGroupColorPalette) {
        expect(specLightTints.containsKey(c.toARGB32()), isTrue,
            reason: 'palette swatch ${c.toARGB32().toRadixString(16)} is missing a tint mapping');
      }
    });

    test('distinct group colors resolve to distinct light tints (not one flat square)', () {
      final tints = <Color>{
        for (final base in specLightTints.keys) groupTint(base, Brightness.light),
      };
      expect(tints.length, specLightTints.length);
    });

    test('distinct group colors resolve to distinct dark tints', () {
      final tints = <Color>{
        for (final base in specLightTints.keys) groupTint(base, Brightness.dark),
      };
      expect(tints.length, specLightTints.length);
    });

    test('dark tint differs from the light tint (derived for dark surfaces, not reused)', () {
      for (final base in specLightTints.keys) {
        expect(
          groupTint(base, Brightness.dark),
          isNot(groupTint(base, Brightness.light)),
          reason: 'dark tint for ${base.toRadixString(16)} must be a dark-surface derivation',
        );
      }
    });

    test('dark tint is dark (legible behind a saturated icon on a dark card)', () {
      for (final base in specLightTints.keys) {
        final t = groupTint(base, Brightness.dark);
        expect(t.computeLuminance(), lessThan(0.35),
            reason: 'dark tint for ${base.toRadixString(16)} should be a dark surface, not a near-white light tint');
      }
    });

    test('unknown legacy color falls back without throwing and is tinted by that color', () {
      const legacy = 0xFF009688; // old teal default
      final light = groupTint(legacy, Brightness.light);
      final dark = groupTint(legacy, Brightness.dark);
      expect(light, isNot(dark));
    });
  });
}
