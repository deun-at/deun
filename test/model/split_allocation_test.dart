import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/currency.dart';
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
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
        currency: Currency.eur,
      );
      expect(a.status, AllocationStatus.under);
      expect(a.fraction, 0.0);
    });
  });

  group('rebalanceExactAmounts', () {
    test('the unlocked included members share what the locked ones leave; '
        'locked and excluded amounts stay', () {
      final amounts = {'a': 9.0, 'b': 6.0, 'c': 4.0};
      final result = rebalanceExactAmounts(
        total: 12,
        enabled: {'a', 'b'},
        locked: {'a'},
        amounts: amounts,
      );
      expect(result, {'a': 9.0, 'b': 3.0, 'c': 4.0});
      // The input map is not changed.
      expect(amounts, {'a': 9.0, 'b': 6.0, 'c': 4.0});
    });

    test('three unlocked members get exact thirds, not cent-rounded parts, '
        'and the split counts as allocated', () {
      final result = rebalanceExactAmounts(
        total: 10,
        enabled: {'a', 'b', 'c'},
        locked: {},
        amounts: {},
      );
      expect(result, {'a': 10 / 3, 'b': 10 / 3, 'c': 10 / 3});
      final allocation = SplitAllocation.compute(
        mode: SplitMode.amount,
        total: 10,
        amounts: result,
        percentages: {},
        parts: {},
        enabled: {'a', 'b', 'c'},
        currency: Currency.eur,
      );
      expect(allocation.status, AllocationStatus.ok);
    });
  });

  group('rebalancePercentages', () {
    test('the unlocked included members share what the locked ones leave of '
        '100; locked and excluded percentages stay', () {
      final result = rebalancePercentages(
        enabled: {'a', 'b', 'c'},
        locked: {'a'},
        percentages: {'a': 50.0, 'd': 10.0},
      );
      expect(result, {'a': 50.0, 'b': 25.0, 'c': 25.0, 'd': 10.0});
    });

    test('three unlocked members get exact thirds of 100, and the split '
        'counts as allocated', () {
      final result = rebalancePercentages(
        enabled: {'a', 'b', 'c'},
        locked: {},
        percentages: {},
      );
      expect(result, {'a': 100 / 3, 'b': 100 / 3, 'c': 100 / 3});
      final allocation = SplitAllocation.compute(
        mode: SplitMode.percentage,
        total: 10,
        amounts: {},
        percentages: result,
        parts: {},
        enabled: {'a', 'b', 'c'},
        currency: Currency.eur,
      );
      expect(allocation.status, AllocationStatus.ok);
    });
  });

  group('rebalancing with nobody to rebalance', () {
    test(
      'no included members: amounts and percentages come back unchanged',
      () {
        expect(
          rebalanceExactAmounts(
            total: 12,
            enabled: {},
            locked: {},
            amounts: {'a': 5.0},
          ),
          {'a': 5.0},
        );
        expect(
          rebalancePercentages(
            enabled: {},
            locked: {},
            percentages: {'a': 40.0},
          ),
          {'a': 40.0},
        );
      },
    );

    test('every included member locked: nothing is reassigned and nothing '
        'turns NaN or Infinity', () {
      final amounts = rebalanceExactAmounts(
        total: 12,
        enabled: {'a', 'b'},
        locked: {'a', 'b'},
        amounts: {'a': 9.0, 'b': 5.0},
      );
      final percentages = rebalancePercentages(
        enabled: {'a', 'b'},
        locked: {'a', 'b'},
        percentages: {'a': 55.0, 'b': 50.0},
      );
      expect(amounts, {'a': 9.0, 'b': 5.0});
      expect(percentages, {'a': 55.0, 'b': 50.0});
    });
  });

  group('scaleLockedAmounts', () {
    test('a locked amount scales with the total; unlocked ones stay', () {
      final amounts = {'a': 9.0, 'b': 3.0};
      final result = scaleLockedAmounts(
        oldTotal: 12,
        newTotal: 24,
        locked: {'a'},
        amounts: amounts,
      );
      expect(result.amounts, {'a': 18.0, 'b': 3.0});
      expect(result.releaseLocks, isFalse);
      // The input map is not changed.
      expect(amounts, {'a': 9.0, 'b': 3.0});
    });

    test('a total at or below zero, or nobody locked, releases the locks and '
        'changes no amount', () {
      const amounts = {'a': 9.0, 'b': 3.0};
      for (final (oldTotal, newTotal, locked) in [
        (0.0, 24.0, {'a'}),
        (12.0, 0.0, {'a'}),
        (12.0, -5.0, {'a'}),
        (12.0, 24.0, <String>{}),
      ]) {
        final result = scaleLockedAmounts(
          oldTotal: oldTotal,
          newTotal: newTotal,
          locked: locked,
          amounts: amounts,
        );
        final reason = '$oldTotal -> $newTotal, locked $locked';
        expect(result.amounts, amounts, reason: reason);
        expect(result.releaseLocks, isTrue, reason: reason);
      }
    });
  });
}
