import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';

void main() {
  group('SplitMode.fromString', () {
    test('"equal" → amount', () {
      expect(SplitMode.fromString('equal'), SplitMode.amount);
    });

    test('"exact" → amount', () {
      expect(SplitMode.fromString('exact'), SplitMode.amount);
    });

    test('"percentage" → percentage', () {
      expect(SplitMode.fromString('percentage'), SplitMode.percentage);
    });

    test('"shares" → shares', () {
      expect(SplitMode.fromString('shares'), SplitMode.shares);
    });

    test('null → amount (default)', () {
      expect(SplitMode.fromString(null), SplitMode.amount);
    });

    test('unknown string → amount (default)', () {
      expect(SplitMode.fromString('unknown'), SplitMode.amount);
    });
  });

  group('SplitMode.toDbValue', () {
    test('amount → "exact"', () {
      expect(SplitMode.amount.toDbValue(), 'exact');
    });

    test('percentage → "percentage"', () {
      expect(SplitMode.percentage.toDbValue(), 'percentage');
    });

    test('shares → "shares"', () {
      expect(SplitMode.shares.toDbValue(), 'shares');
    });
  });

  group('SplitMode round-trip', () {
    test('all modes survive round-trip via toDbValue → fromString', () {
      // Note: amount.toDbValue() = 'exact', fromString('exact') = amount ✓
      for (final mode in SplitMode.values) {
        expect(SplitMode.fromString(mode.toDbValue()), mode);
      }
    });
  });
}
