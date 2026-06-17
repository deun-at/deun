import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClaimUnitRow row(
    String id,
    double cost,
    List<String> claimers,
  ) =>
      ClaimUnitRow(
        entryId: id,
        name: 'Item $id',
        unit: ClaimUnit(unitCost: cost, claimers: claimers),
        claimerNames: {for (final c in claimers) c: c},
      );

  group('ClaimChipState.forPersona', () {
    test('open unit: no claimers → open, not claimed by you', () {
      final s = ClaimChipState.forPersona(row('u1', 4.0, const []), 'me@x');
      expect(s.open, isTrue);
      expect(s.claimedByYou, isFalse);
      expect(s.splitCount, 0);
      expect(s.perUnitCost, 0);
    });

    test('claimed solely by you: claimedByYou, split 1, full unit cost', () {
      final s = ClaimChipState.forPersona(row('u1', 10.0, ['me@x']), 'me@x');
      expect(s.open, isFalse);
      expect(s.claimedByYou, isTrue);
      expect(s.splitCount, 1);
      expect(s.perUnitCost, 10.0);
    });

    test('split between you and another: split 2, half cost each', () {
      final s = ClaimChipState.forPersona(
        row('u1', 6.0, ['me@x', 'other@x']),
        'me@x',
      );
      expect(s.open, isFalse);
      expect(s.claimedByYou, isTrue);
      expect(s.splitCount, 2);
      expect(s.perUnitCost, 3.0);
    });

    test('claimed by others only: not by you, not open, split count set', () {
      final s = ClaimChipState.forPersona(
        row('u1', 6.0, ['a@x', 'b@x']),
        'me@x',
      );
      expect(s.open, isFalse);
      expect(s.claimedByYou, isFalse);
      expect(s.splitCount, 2);
      expect(s.perUnitCost, 3.0);
    });
  });

  group('confirmTotalForPersona', () {
    test('sums the persona share across all units', () {
      final rows = [
        row('u1', 10.0, ['me@x']), // 10 to me
        row('u2', 6.0, ['me@x', 'b@x']), // 3 to me
        row('u3', 4.0, const []), // unclaimed
        row('u4', 8.0, ['b@x']), // none to me
      ];
      expect(confirmTotalForPersona(rows, 'me@x'), 13.0);
    });

    test('persona with no claims totals zero', () {
      final rows = [row('u1', 10.0, ['b@x'])];
      expect(confirmTotalForPersona(rows, 'me@x'), 0.0);
    });
  });
}
