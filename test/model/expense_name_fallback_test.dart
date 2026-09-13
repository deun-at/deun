/// A row with no name must not take down the list it appears in.
///
/// `Expense.name` is a non-nullable `late String` assigned straight from
/// `json["name"]`, so a single null-named row threw a TypeError during parse —
/// and because the whole group's expenses are parsed in one loop, that one row
/// failed the entire list rather than itself.
///
/// The editor bug that could write such a row is fixed separately (the name
/// field's value was cleared by the Quick → Itemized remount; see
/// expense_itemized_editor_test.dart). This is the second layer: whatever the
/// cause — an older client, a direct database edit, a future regression — a
/// missing name degrades to a blank title.
///
/// [Group.name] has carried this fallback all along; Expense was the outlier.
library;

import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({required Object? name}) => {
  'id': 'e1',
  'group_id': 'g1',
  'name': name,
  'expense_date': '2026-01-10',
  'paid_by': 'a@test.com',
  'created_at': '2026-01-10T10:00:00',
  'is_paid_back_row': false,
  'expense_entry': <dynamic>[],
};

void main() {
  group('Expense.name tolerates a missing name', () {
    test('a null name parses to an empty string instead of throwing', () {
      final expense = Expense();

      expect(() => expense.loadDataFromJson(_row(name: null)), returnsNormally);
      expect(expense.name, '');
    });

    test('an absent name key parses to an empty string', () {
      final json = _row(name: null)..remove('name');
      final expense = Expense();

      expect(() => expense.loadDataFromJson(json), returnsNormally);
      expect(expense.name, '');
    });

    test('a real name is untouched', () {
      final expense = Expense()..loadDataFromJson(_row(name: 'Dinner'));

      expect(expense.name, 'Dinner');
    });

    test('one bad row does not fail the rows around it', () {
      // The shape that broke the expense list: a single null-named row in a
      // group whose other rows are fine.
      final rows = [
        _row(name: 'Breakfast'),
        _row(name: null),
        _row(name: 'Taxi'),
      ];

      final parsed = rows.map((json) => Expense()..loadDataFromJson(json));

      expect(parsed.map((e) => e.name), ['Breakfast', '', 'Taxi']);
    });
  });

  group('Group.name already had the fallback', () {
    test('a null group name parses to an empty string', () {
      final group = Group();

      expect(
        () => group.loadDataFromJson({
          'id': 'g1',
          'name': null,
          'simplified_expenses': true,
          'created_at': '2026-01-10T10:00:00',
        }),
        returnsNormally,
      );
      expect(group.name, '');
    });
  });
}
