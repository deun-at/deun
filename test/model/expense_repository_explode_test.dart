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
}
