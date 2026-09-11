import 'package:deun/helper/helper.dart';
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
        shareStat: const {'a@test.com': 10, 'b@test.com': 10, 'c@test.com': 10},
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

    test('shares are whole minor units that sum to the expense total', () {
      // 100.01 split four ways is 25.0025 each. Rounded independently for
      // display that reads 25.00 four times — a cent less than the expense,
      // which is what the read view showed before the residue was distributed.
      final e = _expense(
        amount: 100.01,
        paidBy: 'a@test.com',
        shareStat: const {
          'a@test.com': 25.0025,
          'b@test.com': 25.0025,
          'c@test.com': 25.0025,
          'd@test.com': 25.0025,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const [
          'a@test.com',
          'b@test.com',
          'c@test.com',
          'd@test.com',
        ],
      );

      final sum = rows.fold<double>(0, (s, r) => s + r.share);
      expect(roundCurrency(sum, Currency.eur), 100.01);
      for (final r in rows) {
        expect(r.share, roundCurrency(r.share, Currency.eur));
      }
    });

    test('the payer net stays total minus their own apportioned share', () {
      final e = _expense(
        amount: 100.01,
        paidBy: 'a@test.com',
        shareStat: const {
          'a@test.com': 25.0025,
          'b@test.com': 25.0025,
          'c@test.com': 25.0025,
          'd@test.com': 25.0025,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const [
          'a@test.com',
          'b@test.com',
          'c@test.com',
          'd@test.com',
        ],
      );

      final payer = rows.firstWhere((r) => r.email == 'a@test.com');
      expect(payer.net, roundCurrency(100.01 - payer.share, Currency.eur));
      // What the payer lent is exactly what the others owe.
      final owed = rows
          .where((r) => !r.isPayer)
          .fold<double>(0, (s, r) => s + r.share);
      expect(roundCurrency(owed, Currency.eur), payer.net);
    });

    test('the spare cent falls on the payer, not on whoever sorts first', () {
      // 10.00 across three is 3.3333 each, so exactly one share rounds up. The
      // payer carries it: they are already fronting the money, and breaking the
      // tie alphabetically would quietly tax the same member in every group
      // they are in.
      final e = _expense(
        amount: 10.00,
        paidBy: 'zoe@test.com',
        shareStat: const {
          'ann@test.com': 10 / 3,
          'bob@test.com': 10 / 3,
          'zoe@test.com': 10 / 3,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['ann@test.com', 'bob@test.com', 'zoe@test.com'],
      );

      expect(rows.firstWhere((r) => r.email == 'zoe@test.com').share, 3.34);
      expect(rows.firstWhere((r) => r.email == 'ann@test.com').share, 3.33);
      expect(rows.firstWhere((r) => r.email == 'bob@test.com').share, 3.33);
      // Still fully allocated, and the payer is owed a cent less for it.
      expect(rows.fold<double>(0, (s, r) => s + r.share), 10.00);
      expect(rows.firstWhere((r) => r.email == 'zoe@test.com').net, 6.66);
    });

    test('a payer who is not in the split does not take the spare cent', () {
      // Nothing to absorb it with: the payer holds no share, so the remainder
      // has to fall on a participant and the key order decides.
      final e = _expense(
        amount: 10.00,
        paidBy: 'zoe@test.com',
        shareStat: const {
          'ann@test.com': 10 / 3,
          'bob@test.com': 10 / 3,
          'cid@test.com': 10 / 3,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const [
          'ann@test.com',
          'bob@test.com',
          'cid@test.com',
          'zoe@test.com',
        ],
      );

      final shares = rows
          .where((r) => r.email != 'zoe@test.com')
          .fold<double>(0, (s, r) => s + r.share);
      expect(shares, 10.00);
      expect(rows.firstWhere((r) => r.email == 'zoe@test.com').share, 0);
    });

    test('nothing is lost across a run of uneven splits', () {
      // The cent that cannot be divided has to land on somebody — what must
      // never happen is that it lands on nobody. Stated exactly: for every
      // expense the members' nets sum to zero, so the books balance however
      // badly the amount divides, and a long run of awkward splits cannot
      // drift.
      const currency = Currency.eur;
      const totals = [10.00, 0.01, 0.05, 100.01, 45.00, 33.33, 20.00, 0.03];
      const sizes = [2, 3, 4, 5, 6, 7];

      var runningNet = 0.0;
      for (final total in totals) {
        for (final n in sizes) {
          final emails = [for (var i = 0; i < n; i++) 'm$i@test.com'];
          final e = _expense(
            amount: total,
            paidBy: emails.first,
            // An equal split as the ledger stores it: percentage-derived, so
            // every share carries the same unrepresentable fraction.
            shareStat: {for (final m in emails) m: total / n},
          );

          final rows = buildMemberBreakdown(expense: e, memberEmails: emails);

          final shares = rows.fold<double>(0, (s, r) => s + r.share);
          expect(
            roundCurrency(shares, currency),
            roundCurrency(total, currency),
            reason: '$total across $n must be fully allocated',
          );

          final nets = rows.fold<double>(0, (s, r) => s + r.net);
          expect(
            roundCurrency(nets, currency),
            0.0,
            reason: 'nets for $total across $n must cancel',
          );
          runningNet += nets;
        }
      }

      // The whole run together, not just each expense on its own: a residue
      // that leaked a fraction each time would show up here even if every
      // individual assertion rounded away.
      expect(roundCurrency(runningNet, currency), 0.0);
    });

    test('apportioning ignores members the caller did not ask for', () {
      // The read view asks for a single member to compute their own net; the
      // residue must still be spread across everyone who holds a share, not
      // dumped on whoever was requested.
      final e = _expense(
        amount: 100.01,
        paidBy: 'a@test.com',
        shareStat: const {
          'a@test.com': 25.0025,
          'b@test.com': 25.0025,
          'c@test.com': 25.0025,
          'd@test.com': 25.0025,
        },
      );

      final rows = buildMemberBreakdown(
        expense: e,
        memberEmails: const ['b@test.com'],
      );

      expect(rows.length, 1);
      expect(rows.single.share, closeTo(25.0, 0.011));
    });
  });
}
