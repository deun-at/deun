import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/constants.dart';

void main() {
  group('kSheetAnimationStyle', () {
    test('encodes the DESIGN_SPEC sheet-rise duration and curve', () {
      expect(kSheetAnimationStyle.duration, const Duration(milliseconds: 280));
      expect(kSheetAnimationStyle.curve, const Cubic(0.22, 1.0, 0.36, 1.0));
    });

    test('reverse uses the spec curve over a faster duration', () {
      expect(
        kSheetAnimationStyle.reverseDuration,
        const Duration(milliseconds: 200),
      );
      expect(
        kSheetAnimationStyle.reverseCurve,
        const Cubic(0.22, 1.0, 0.36, 1.0),
      );
    });
  });
}
