import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';

void main() {
  group('ExpenseRepository.explodeItemizedEntry', () {
    test('qty 3 item becomes 3 unit entries each amount = unit price', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 5.0,
        quantity: 3,
        itemGroupSeq: 1,
        sortIdStart: 10,
      );

      expect(units.length, 3);
      for (final unit in units) {
        final entry = unit['entry'] as Map<String, dynamic>;
        expect(entry['amount'], 5.0);
        expect(entry['quantity'], 1);
        expect(entry['split_mode'], 'claim');
        expect(entry['item_group_seq'], 1);
        expect(entry['name'], 'Beer');
        expect((unit['shares'] as List).isEmpty, isTrue); // new units start unclaimed
      }
    });

    test('sort_id increments per unit so order is stable', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer', unitPrice: 5.0, quantity: 2,
        itemGroupSeq: 1, sortIdStart: 20,
      );
      expect((units[0]['entry'] as Map)['sort_id'], 20);
      expect((units[1]['entry'] as Map)['sort_id'], 21);
    });

    test('qty 1 produces exactly one unit', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Wine', unitPrice: 8.5, quantity: 1,
        itemGroupSeq: 2, sortIdStart: 10,
      );
      expect(units.length, 1);
      expect((units[0]['entry'] as Map)['amount'], 8.5);
    });

    test('qty 0 is treated as 1 (guard)', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Odd', unitPrice: 2.0, quantity: 0,
        itemGroupSeq: 3, sortIdStart: 10,
      );
      expect(units.length, 1);
    });
  });

  group('ExpenseRepository.explodeItemizedEntry with unitClaims (F146)', () {
    test('existing claims are preserved per unit on re-explode', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer', unitPrice: 2.5, quantity: 3,
        itemGroupSeq: 1, sortIdStart: 10,
        unitClaims: [
          ['a@test.com'],
          [],
          ['a@test.com', 'b@test.com'],
        ],
      );

      expect(units.length, 3);
      final shares0 = units[0]['shares'] as List;
      expect(shares0.length, 1);
      expect((shares0[0] as Map)['email'], 'a@test.com');
      expect((shares0[0] as Map)['percentage'], 100);

      expect((units[1]['shares'] as List), isEmpty);

      final shares2 = units[2]['shares'] as List;
      expect(shares2.length, 2);
      expect((shares2[0] as Map)['percentage'], 50);
      expect((shares2[1] as Map)['percentage'], 50);
    });

    test('units beyond the old quantity start unclaimed', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer', unitPrice: 2.5, quantity: 3,
        itemGroupSeq: 1, sortIdStart: 10,
        unitClaims: [
          ['a@test.com'],
        ],
      );
      expect((units[0]['shares'] as List).length, 1);
      expect((units[1]['shares'] as List), isEmpty);
      expect((units[2]['shares'] as List), isEmpty);
    });

    test('shrinking the quantity drops trailing claims', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer', unitPrice: 2.5, quantity: 1,
        itemGroupSeq: 1, sortIdStart: 10,
        unitClaims: [
          ['a@test.com'],
          ['b@test.com'],
        ],
      );
      expect(units.length, 1);
      expect(((units[0]['shares'] as List)[0] as Map)['email'], 'a@test.com');
    });
  });
}
