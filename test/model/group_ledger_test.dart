import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/presentation/group_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal [Expense] for classifier/grouping tests without touching
/// Supabase or JSON parsing.
Expense _expense({
  required String id,
  required String date,
  String createdAt = '',
  bool isPaidBackRow = false,
  int entryCount = 1,
}) {
  final e = Expense();
  e.id = id;
  e.groupId = 'g';
  e.name = 'Expense $id';
  e.amount = 10;
  e.paidBy = 'me@test.com';
  e.expenseDate = date;
  e.createdAt = createdAt;
  e.isPaidBackRow = isPaidBackRow;
  e.category = null;
  e.paidByDisplayName = 'Me';
  e.groupMemberShareStatistic = {};
  e.expenseEntries = {
    for (var i = 0; i < entryCount; i++) 'entry$i': ExpenseEntry(index: i),
  };
  return e;
}

void main() {
  group('classifyLedgerRow', () {
    test('payback row when isPaidBackRow is true', () {
      final e = _expense(id: '1', date: '2026-01-01', isPaidBackRow: true);
      expect(classifyLedgerRow(e), LedgerRowType.payback);
    });

    test('payback wins even with multiple entries', () {
      final e = _expense(id: '1', date: '2026-01-01', isPaidBackRow: true, entryCount: 3);
      expect(classifyLedgerRow(e), LedgerRowType.payback);
    });

    test('quick expense for a single entry', () {
      final e = _expense(id: '1', date: '2026-01-01', entryCount: 1);
      expect(classifyLedgerRow(e), LedgerRowType.quick);
    });

    test('itemized expense for multiple entries', () {
      final e = _expense(id: '1', date: '2026-01-01', entryCount: 3);
      expect(classifyLedgerRow(e), LedgerRowType.itemized);
    });
  });

  group('groupExpensesByDay', () {
    test('groups expenses sharing a calendar day under one section', () {
      final expenses = [
        _expense(id: 'a', date: '2026-01-02T20:00:00', createdAt: '2'),
        _expense(id: 'b', date: '2026-01-02T08:00:00', createdAt: '1'),
        _expense(id: 'c', date: '2026-01-01T12:00:00', createdAt: '0'),
      ];

      final sections = groupExpensesByDay(expenses);

      expect(sections.length, 2);
      expect(sections.first.expenses.map((e) => e.id).toList(), ['a', 'b']);
      expect(sections.last.expenses.map((e) => e.id).toList(), ['c']);
    });

    test('preserves the incoming (descending) order of days and rows', () {
      final expenses = [
        _expense(id: 'newest', date: '2026-03-10T00:00:00'),
        _expense(id: 'older', date: '2026-03-09T00:00:00'),
      ];

      final sections = groupExpensesByDay(expenses);

      expect(sections.map((s) => s.expenses.first.id).toList(), ['newest', 'older']);
      expect(sections.first.day.isAfter(sections.last.day), isTrue);
    });

    test('empty input yields no sections', () {
      expect(groupExpensesByDay([]), isEmpty);
    });

    test('section day is normalized to midnight', () {
      final sections = groupExpensesByDay([_expense(id: 'a', date: '2026-05-04T15:30:00')]);
      final day = sections.single.day;
      expect([day.year, day.month, day.day], [2026, 5, 4]);
      expect([day.hour, day.minute, day.second], [0, 0, 0]);
    });
  });
}
