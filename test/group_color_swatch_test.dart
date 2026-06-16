import 'package:deun/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectedGroupSwatchIndex', () {
    test('returns the matching palette index for a known color value', () {
      for (var i = 0; i < kGroupColorPalette.length; i++) {
        expect(
          selectedGroupSwatchIndex(kGroupColorPalette[i].toARGB32()),
          i,
        );
      }
    });

    test('defaults to the first swatch when value is null', () {
      expect(selectedGroupSwatchIndex(null), 0);
    });

    test('defaults to the first swatch when value is not in the palette', () {
      expect(selectedGroupSwatchIndex(const Color(0xFF000000).toARGB32()), 0);
    });
  });
}
