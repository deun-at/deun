import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';

void main() {
  group('ExpenseEntry.loadDataFromJson', () {
    test('loads all fields', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Milk',
        'amount': 3.50,
        'quantity': 2,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.id, 'e1');
      expect(entry.expenseId, 'exp1');
      expect(entry.name, 'Milk');
      expect(entry.amount, 3.5);
      expect(entry.quantity, 2);
      expect(entry.splitMode, 'equal');
    });

    test('amount defaults to 0 when null', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': null,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.amount, 0.0);
    });

    test('amount parses from int', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': 5,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.amount, 5.0);
    });

    test('amount parses from string', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': '3.50',
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.amount, 3.5);
    });

    test('quantity defaults to 1 when null', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': 10,
        'quantity': null,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.quantity, 1);
    });

    test('split_mode defaults to equal when missing', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': 10,
        'quantity': 1,
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.splitMode, 'equal');
    });

    test('loads expense entry shares', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': 10,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
        'expense_entry_share': [
          {
            'expense_entry_id': 'e1',
            'email': 'user@test.com',
            'display_name': 'User',
            'percentage': 50.0,
            'is_locked': false,
            'created_at': '2024-03-15T10:00:00',
          }
        ],
      });

      expect(entry.expenseEntryShares.length, 1);
      expect(entry.expenseEntryShares[0].email, 'user@test.com');
      expect(entry.expenseEntryShares[0].percentage, 50.0);
    });
  });

  group('ExpenseEntry.unitPrice', () {
    test('calculates unit price', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 15.0,
        'quantity': 3,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.unitPrice, 5.0);
    });

    test('quantity 0 returns amount (guard)', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1',
        'expense_id': 'exp1',
        'name': 'Test',
        'amount': 10.0,
        'quantity': 0,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      // quantity parsed as 0 via int.tryParse
      // But default is 1 for null — 0 is explicitly set
      // unitPrice: quantity > 0 ? amount / quantity : amount
      expect(entry.unitPrice, 10.0);
    });
  });

  group('ExpenseEntryShare.loadDataFromJson', () {
    test('loads all fields', () {
      final share = ExpenseEntryShare();
      share.loadDataFromJson({
        'expense_entry_id': 'e1',
        'email': 'user@test.com',
        'display_name': 'User',
        'percentage': 33.33,
        'fixed_amount': 5.0,
        'parts': 2,
        'is_locked': true,
        'created_at': '2024-03-15T10:00:00',
      });

      expect(share.expenseEntryId, 'e1');
      expect(share.email, 'user@test.com');
      expect(share.percentage, 33.33);
      expect(share.fixedAmount, 5.0);
      expect(share.parts, 2);
      expect(share.isLocked, true);
    });

    test('nullable fields default correctly', () {
      final share = ExpenseEntryShare();
      share.loadDataFromJson({
        'expense_entry_id': 'e1',
        'email': 'user@test.com',
        'display_name': 'User',
        'percentage': 50,
        'is_locked': false,
        'created_at': '2024-03-15T10:00:00',
      });

      expect(share.fixedAmount, isNull);
      expect(share.parts, isNull);
      expect(share.isLocked, false);
    });

    test('percentage parses from int', () {
      final share = ExpenseEntryShare();
      share.loadDataFromJson({
        'expense_entry_id': 'e1',
        'email': 'user@test.com',
        'display_name': 'User',
        'percentage': 100,
        'is_locked': false,
        'created_at': '2024-03-15T10:00:00',
      });

      expect(share.percentage, 100.0);
    });

    test('is_locked false when not true', () {
      final share = ExpenseEntryShare();
      share.loadDataFromJson({
        'expense_entry_id': 'e1',
        'email': 'user@test.com',
        'display_name': 'User',
        'percentage': 50,
        'is_locked': null,
        'created_at': '2024-03-15T10:00:00',
      });

      expect(share.isLocked, false);
    });
  });
}
