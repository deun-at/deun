import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';

Map<String, dynamic> _unitJson(
  String id,
  String? groupId, {
  String name = 'Beer',
  double amount = 2.5,
  List<String> claimers = const [],
}) {
  return {
    'id': id,
    'expense_id': 'exp1',
    'name': name,
    'amount': amount,
    'quantity': 1,
    'split_mode': 'claim',
    'item_group_id': groupId,
    'created_at': '2026-07-01T10:00:00',
    'expense_entry_share': claimers
        .map((email) => {
              'expense_entry_id': id,
              'email': email,
              'display_name': email,
              'percentage': 100 / claimers.length,
              'created_at': '2026-07-01T10:00:00',
            })
        .toList(),
  };
}

Expense _expenseWith(List<Map<String, dynamic>> entries) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'exp1',
    'group_id': 'g1',
    'name': 'Kiosk',
    'expense_date': '2026-07-01',
    'paid_by': 'a@test.com',
    'created_at': '2026-07-01T10:00:00',
    'is_paid_back_row': false,
    'expense_entry': entries,
  });
  return e;
}

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

  group('Expense.editorEntries (F146 edit round-trip)', () {
    test('claim units regroup into one qty-N entry per item_group_id', () {
      final expense = _expenseWith([
        _unitJson('u1', 'grp-1', claimers: ['b@test.com']),
        _unitJson('u2', 'grp-1'),
        _unitJson('u3', 'grp-2', name: 'Wine', amount: 8.0),
      ]);

      final entries = expense.editorEntries;
      expect(entries.length, 2);

      final beer = entries[0];
      expect(beer.name, 'Beer');
      expect(beer.quantity, 2);
      expect(beer.amount, 5.0);
      expect(beer.unitPrice, 2.5);
      // Per-unit claims preserved in unit order.
      expect(beer.unitClaims, [
        ['b@test.com'],
        <String>[],
      ]);

      final wine = entries[1];
      expect(wine.quantity, 1);
      expect(wine.unitPrice, 8.0);
      expect(wine.unitClaims, [<String>[]]);

      // Indices are dense and sequential (form field names).
      expect(entries[0].index, 0);
      expect(entries[1].index, 1);
    });

    test('non-claim entries pass through ungrouped', () {
      final expense = _expenseWith([
        {
          'id': 'e1',
          'expense_id': 'exp1',
          'name': 'Dinner',
          'amount': 40.0,
          'quantity': 1,
          'split_mode': 'equal',
          'created_at': '2026-07-01T10:00:00',
          'expense_entry_share': [
            {
              'expense_entry_id': 'e1',
              'email': 'a@test.com',
              'display_name': 'a',
              'percentage': 100.0,
              'created_at': '2026-07-01T10:00:00',
            }
          ],
        },
      ]);

      final entries = expense.editorEntries;
      expect(entries.length, 1);
      expect(entries[0].name, 'Dinner');
      expect(entries[0].quantity, 1);
      expect(entries[0].unitClaims, isEmpty);
      expect(entries[0].expenseEntryShares.length, 1);
    });

    test('claim units without item_group_id stay standalone', () {
      final expense = _expenseWith([
        _unitJson('u1', null, claimers: ['b@test.com']),
        _unitJson('u2', null),
      ]);

      final entries = expense.editorEntries;
      expect(entries.length, 2);
      expect(entries[0].quantity, 1);
      expect(entries[0].unitClaims, [
        ['b@test.com'],
      ]);
    });

    test('toJson seeds the unit price for regrouped claim items', () {
      final expense = _expenseWith([
        _unitJson('u1', 'grp-1'),
        _unitJson('u2', 'grp-1'),
      ]);

      final json = expense.toJson();
      expect(json['expense_entry[0][amount]'], '2.50');
      expect(json['expense_entry[0][name]'], 'Beer');
      expect(json.containsKey('expense_entry[1][amount]'), isFalse);
    });
  });
}
