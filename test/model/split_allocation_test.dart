import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/split_allocation.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';

void main() {
  group('SplitAllocation.compute — equal mode', () {
    test('any included members → ok, fraction 1', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.equal,
        total: 12,
        amounts: {},
        percentages: {},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.ok);
      expect(a.fraction, 1.0);
      expect(a.remaining, 0);
    });

    test('no members enabled → under', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.equal,
        total: 12,
        amounts: {},
        percentages: {},
        parts: {},
        enabled: {},
      );
      expect(a.status, AllocationStatus.under);
      expect(a.fraction, 0.0);
    });
  });

  group('SplitAllocation.compute — amount mode', () {
    test('fully allocated → ok, fraction 1.0', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: {'a': 5, 'b': 5},
        percentages: {},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.ok);
      expect(a.fraction, closeTo(1.0, 1e-9));
      expect(a.remaining, closeTo(0, 1e-9));
    });

    test('under-allocated → under, fraction < 1', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: {'a': 3, 'b': 4},
        percentages: {},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.under);
      expect(a.fraction, closeTo(0.7, 1e-9));
      expect(a.remaining, closeTo(3, 1e-9));
    });

    test('over-allocated → over, fraction clamped to 1', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: {'a': 8, 'b': 5},
        percentages: {},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.over);
      expect(a.fraction, 1.0);
      expect(a.remaining, closeTo(-3, 1e-9));
    });

    test('cent-level tolerance: 0.004 over still counts as ok', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: {'a': 5, 'b': 5.004},
        percentages: {},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.ok);
    });
  });

  group('SplitAllocation.compute — percentage mode', () {
    test('100% → ok', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.percentage,
        total: 50,
        amounts: {},
        percentages: {'a': 60, 'b': 40},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.ok);
      expect(a.fraction, closeTo(1.0, 1e-9));
    });

    test('80% → under, fraction 0.8', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.percentage,
        total: 50,
        amounts: {},
        percentages: {'a': 50, 'b': 30},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.under);
      expect(a.fraction, closeTo(0.8, 1e-9));
    });

    test('120% → over, fraction clamped', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.percentage,
        total: 50,
        amounts: {},
        percentages: {'a': 70, 'b': 50},
        parts: {},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.over);
      expect(a.fraction, 1.0);
    });
  });

  group('SplitAllocation.compute — shares mode', () {
    test('any positive total parts → ok, fraction 1', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.shares,
        total: 30,
        amounts: {},
        percentages: {},
        parts: {'a': 1, 'b': 2},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.ok);
      expect(a.fraction, 1.0);
    });

    test('no parts (all zero) → under', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.shares,
        total: 30,
        amounts: {},
        percentages: {},
        parts: {'a': 0, 'b': 0},
        enabled: {'a', 'b'},
      );
      expect(a.status, AllocationStatus.under);
    });
  });

  group('SplitAllocation.compute — no members enabled', () {
    test('empty enabled set → under, fraction 0', () {
      final a = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: {},
        percentages: {},
        parts: {},
        enabled: {},
      );
      expect(a.status, AllocationStatus.under);
      expect(a.fraction, 0.0);
    });
  });
}
