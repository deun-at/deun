import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('barFraction', () {
    test('returns 0 when max is 0 (avoids divide-by-zero)', () {
      expect(barFraction(0, 0), 0.0);
      expect(barFraction(5, 0), 0.0);
    });

    test('returns value / max for a positive max', () {
      expect(barFraction(5, 10), 0.5);
      expect(barFraction(10, 10), 1.0);
    });

    test('clamps the fraction into 0..1', () {
      expect(barFraction(20, 10), 1.0);
      expect(barFraction(-5, 10), 0.0);
    });
  });

  group('maxOfBars', () {
    test('returns 0 for an empty list', () {
      expect(maxOfBars(const []), 0.0);
    });

    test('returns the largest value across all bars', () {
      expect(maxOfBars(const [1, 7, 3]), 7.0);
    });

    test('considers every value passed in each tuple', () {
      // paid vs fair-share: both must be considered for a shared scale.
      expect(maxOfBars(const [3, 9, 2, 4]), 9.0);
    });
  });

  group('labelStep', () {
    test('is 1 for short series', () {
      expect(labelStep(6), 1);
      expect(labelStep(1), 1);
    });

    test('thins labels for long series so roughly 6 show', () {
      expect(labelStep(12), 2);
      expect(labelStep(24), 4);
    });

    test('never returns less than 1', () {
      expect(labelStep(0), 1);
    });
  });

  group('percentOfTotal', () {
    test('returns 0 when total is 0', () {
      expect(percentOfTotal(5, 0), 0.0);
    });

    test('returns share * 100', () {
      expect(percentOfTotal(25, 100), 25.0);
      expect(percentOfTotal(1, 4), 25.0);
    });
  });
}
