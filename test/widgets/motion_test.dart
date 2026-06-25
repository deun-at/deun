// ignore_for_file: avoid_redundant_argument_values

import 'package:deun/widgets/motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Curve identity: every Cubic maps 0→0 and 1→1.
  // Interior samples pin the control points — if a constant is mis-typed the
  // expected value (computed from the same Cubic) diverges.
  // ---------------------------------------------------------------------------
  group('Motion curves — boundary values', () {
    final cases = <String, Cubic>{
      'screenPush':  Motion.screenPush,
      'barGrow':     Motion.barGrow,
      'sheetRise':   Motion.sheetRise,
      'successPop':  Motion.successPop,
      'tabPill':     Motion.tabPill,
    };

    for (final entry in cases.entries) {
      test('${entry.key} maps 0→0 and 1→1', () {
        expect(entry.value.transform(0.0), closeTo(0.0, 1e-10));
        expect(entry.value.transform(1.0), closeTo(1.0, 1e-10));
      });
    }
  });

  group('Motion curves — control-point identity (pins exact cubic-bezier)', () {
    test('screenPush equals Cubic(0.2, 0.8, 0.2, 1)', () {
      expect(Motion.screenPush, equals(const Cubic(0.2, 0.8, 0.2, 1)));
    });

    test('barGrow equals Cubic(0.2, 0.85, 0.2, 1)', () {
      expect(Motion.barGrow, equals(const Cubic(0.2, 0.85, 0.2, 1)));
    });

    test('sheetRise equals Cubic(0.22, 1, 0.36, 1)', () {
      expect(Motion.sheetRise, equals(const Cubic(0.22, 1.0, 0.36, 1.0)));
    });

    test('successPop equals Cubic(0.2, 0.9, 0.3, 1.2)', () {
      expect(Motion.successPop, equals(const Cubic(0.2, 0.9, 0.3, 1.2)));
    });

    test('tabPill equals Cubic(0.34, 1.4, 0.5, 1)', () {
      expect(Motion.tabPill, equals(const Cubic(0.34, 1.4, 0.5, 1)));
    });
  });

  // ---------------------------------------------------------------------------
  // Duration constants — value equality against spec ms.
  // ---------------------------------------------------------------------------
  group('Motion durations — screen transitions', () {
    test('screenForward is 360 ms', () {
      expect(Motion.screenForward, const Duration(milliseconds: 360));
    });

    test('tabSwitch is 260 ms', () {
      expect(Motion.tabSwitch, const Duration(milliseconds: 260));
    });
  });

  group('Motion durations — staggered list', () {
    test('listItem is 440 ms', () {
      expect(Motion.listItem, const Duration(milliseconds: 440));
    });

    test('listStagger is 50 ms', () {
      expect(Motion.listStagger, const Duration(milliseconds: 50));
    });

    test('listStaggerCap is 380 ms', () {
      expect(Motion.listStaggerCap, const Duration(milliseconds: 380));
    });
  });

  group('Motion durations — count-up', () {
    test('countUp is 750 ms', () {
      expect(Motion.countUp, const Duration(milliseconds: 750));
    });
  });

  group('Motion durations — success pop + ring', () {
    test('successPopDuration is 500 ms', () {
      expect(Motion.successPopDuration, const Duration(milliseconds: 500));
    });

    test('successRing is 850 ms', () {
      expect(Motion.successRing, const Duration(milliseconds: 850));
    });

    test('successRingDelay is 100 ms', () {
      expect(Motion.successRingDelay, const Duration(milliseconds: 100));
    });
  });

  group('Motion durations — charts & progress', () {
    test('barGrowDuration is 620 ms', () {
      expect(Motion.barGrowDuration, const Duration(milliseconds: 620));
    });

    test('fillGrow is 720 ms', () {
      expect(Motion.fillGrow, const Duration(milliseconds: 720));
    });

    test('fillGrowDelay is 100 ms', () {
      expect(Motion.fillGrowDelay, const Duration(milliseconds: 100));
    });
  });

  group('Motion durations — sheet rise', () {
    test('sheetRiseDuration is 280 ms', () {
      expect(Motion.sheetRiseDuration, const Duration(milliseconds: 280));
    });

    test('scrimFade is 200 ms', () {
      expect(Motion.scrimFade, const Duration(milliseconds: 200));
    });
  });

  group('Motion durations — looping / ambient', () {
    test('scanSweep is 2400 ms', () {
      expect(Motion.scanSweep, const Duration(milliseconds: 2400));
    });

    test('presencePulse is 1600 ms', () {
      expect(Motion.presencePulse, const Duration(milliseconds: 1600));
    });

    test('darkModeFlip is 280 ms', () {
      expect(Motion.darkModeFlip, const Duration(milliseconds: 280));
    });
  });

  // ---------------------------------------------------------------------------
  // reducedIfNeeded — pure helper, no BuildContext required.
  // ---------------------------------------------------------------------------
  group('reducedIfNeeded', () {
    const base = Duration(milliseconds: 400);

    test('returns Duration.zero when reduceMotion is true', () {
      expect(reducedIfNeeded(base, reduceMotion: true), Duration.zero);
    });

    test('returns the original duration when reduceMotion is false', () {
      expect(reducedIfNeeded(base, reduceMotion: false), base);
    });

    test('works with Duration.zero base and reduceMotion false', () {
      expect(reducedIfNeeded(Duration.zero, reduceMotion: false), Duration.zero);
    });

    test('works with long duration and reduceMotion true', () {
      expect(
        reducedIfNeeded(const Duration(seconds: 10), reduceMotion: true),
        Duration.zero,
      );
    });
  });
}
