import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_detail_view_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [Expense] for pure view-model tests (no Supabase / JSON).
Expense _expense({
  required double amount,
  required String paidBy,
  required Map<String, double> shareStat,
  int entryCount = 1,
}) {
  final e = Expense();
  e.id = '1';
  e.groupId = 'g';
  e.name = 'Dinner';
  e.amount = amount;
  e.paidBy = paidBy;
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.paidByDisplayName = 'Payer';
  e.groupMemberShareStatistic = shareStat;
  e.expenseEntries = {
    for (var i = 0; i < entryCount; i++) 'entry$i': ExpenseEntry(index: i),
  };
  return e;
}

void main() {
  group('isItemizedExpense', () {
    test('false for a single entry (quick)', () {
      final e = _expense(
        amount: 10,
        paidBy: 'a@test.com',
        shareStat: const {},
        entryCount: 1,
      );
      expect(isItemizedExpense(e), isFalse);
    });

    test('true for multiple entries', () {
      final e = _expense(
        amount: 30,
        paidBy: 'a@test.com',
        shareStat: const {},
        entryCount: 3,
      );
      expect(isItemizedExpense(e), isTrue);
    });
  });

  group('buildMemberBreakdown', () {
    test('payer net is positive (lent), other members owe their share', () {
      final e = _expense(
        amount: 30,
        paidBy: 'a@test.com',
        shareStat: const {
          'a@test.com': 10,
          'b@test.com': 10,
          'c@test.com': 10,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['a@test.com', 'b@test.com', 'c@test.com'],
      );

      expect(rows.length, 3);

      final payer = rows.firstWhere((r) => r.email == 'a@test.com');
      expect(payer.isPayer, isTrue);
      expect(payer.share, 10);
      // total 30 − own share 10 = lent 20
      expect(payer.net, 20);

      final b = rows.firstWhere((r) => r.email == 'b@test.com');
      expect(b.isPayer, isFalse);
      expect(b.share, 10);
      expect(b.net, -10);
    });

    test('preserves the requested member order', () {
      final e = _expense(
        amount: 20,
        paidBy: 'b@test.com',
        shareStat: const {'a@test.com': 10, 'b@test.com': 10},
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['b@test.com', 'a@test.com'],
      );

      expect(rows.map((r) => r.email).toList(), ['b@test.com', 'a@test.com']);
    });

    test('omits members not involved and with no share', () {
      final e = _expense(
        amount: 10,
        paidBy: 'a@test.com',
        shareStat: const {'a@test.com': 5, 'b@test.com': 5},
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['a@test.com', 'b@test.com', 'c@test.com'],
      );

      expect(rows.map((r) => r.email).toList(), ['a@test.com', 'b@test.com']);
    });

    test('payer with no share entry still appears (lent the full amount)', () {
      final e = _expense(
        amount: 10,
        paidBy: 'a@test.com',
        shareStat: const {'b@test.com': 10},
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['a@test.com', 'b@test.com'],
      );

      final payer = rows.firstWhere((r) => r.email == 'a@test.com');
      expect(payer.share, 0);
      expect(payer.net, 10);
    });
  });
}
