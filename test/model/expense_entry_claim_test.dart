import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';

void main() {
  group('ExpenseEntry.itemGroupId', () {
    test('loads item_group_id when present', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 5.0,
        'quantity': 1,
        'split_mode': 'claim',
        'item_group_id': 'grp-1',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.itemGroupId, 'grp-1');
    });

    test('item_group_id is null when absent', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 5.0,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.itemGroupId, isNull);
    });
  });

  group('ExpenseEntry.isClaimUnit', () {
    test('true when split_mode is claim and quantity is 1', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1', 'expense_id': 'exp1', 'name': 'Beer',
        'amount': 5.0, 'quantity': 1, 'split_mode': 'claim',
        'item_group_id': 'grp-1', 'created_at': '2024-03-15T10:00:00',
      });
      expect(entry.isClaimUnit, isTrue);
    });

    test('false for a regular equal-split entry', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1', 'expense_id': 'exp1', 'name': 'Dinner',
        'amount': 40.0, 'quantity': 1, 'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });
      expect(entry.isClaimUnit, isFalse);
    });
  });
}
