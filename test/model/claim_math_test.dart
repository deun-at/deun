import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';

void main() {
  // Helper to build a unit: cost + list of claimer emails.
  ClaimUnit u(double cost, List<String> claimers) =>
      ClaimUnit(unitCost: cost, claimers: claimers);

  group('memberShareTotals', () {
    test('single claimer pays full unit cost', () {
      final totals = memberShareTotals([u(5.0, ['sam@x'])]);
      expect(totals['sam@x'], 5.0);
    });

    test('split one unit between two claimers', () {
      final totals = memberShareTotals([u(6.0, ['sam@x', 'priya@x'])]);
      expect(totals['sam@x'], 3.0);
      expect(totals['priya@x'], 3.0);
    });

    test('sums a member across multiple units', () {
      final totals = memberShareTotals([
        u(5.0, ['sam@x']),
        u(6.0, ['sam@x', 'priya@x']),
      ]);
      expect(totals['sam@x'], 8.0); // 5 + 3
      expect(totals['priya@x'], 3.0);
    });

    test('unclaimed unit contributes to nobody', () {
      final totals = memberShareTotals([u(5.0, [])]);
      expect(totals.isEmpty, isTrue);
    });
  });

  group('claimedTotal / unclaimedTotal', () {
    test('claimed sums only units with >=1 claimer', () {
      final units = [u(5.0, ['sam@x']), u(4.0, []), u(6.0, ['priya@x'])];
      expect(claimedTotal(units), 11.0);
    });

    test('unclaimed = grand total - claimed', () {
      final units = [u(5.0, ['sam@x']), u(4.0, []), u(6.0, ['priya@x'])];
      expect(unclaimedTotal(units), 4.0);
    });

    test('all claimed -> unclaimed is zero', () {
      final units = [u(5.0, ['sam@x']), u(6.0, ['priya@x'])];
      expect(unclaimedTotal(units), 0.0);
    });

    test('none claimed -> claimed is zero, unclaimed is total', () {
      final units = [u(5.0, []), u(6.0, [])];
      expect(claimedTotal(units), 0.0);
      expect(unclaimedTotal(units), 11.0);
    });

    test('claimers can exceed an integer share without error (3-way)', () {
      final totals = memberShareTotals([u(10.0, ['a', 'b', 'c'])]);
      expect(totals['a']!, closeTo(3.3333, 0.0001));
      expect(totals['b']!, closeTo(3.3333, 0.0001));
      expect(totals['c']!, closeTo(3.3333, 0.0001));
    });
  });
}
