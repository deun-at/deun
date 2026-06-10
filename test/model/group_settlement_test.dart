import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/groups/data/group_model.dart';

const me = 'me@test.com';
const alice = 'alice@test.com';
const bob = 'bob@test.com';
const carol = 'carol@test.com';

/// Builds a group_shares_summary row as returned by Supabase.
Map<String, dynamic> row({
  required String paidBy,
  required String paidFor,
  double shareAmount = 0,
  double totalExpenses = 0,
  double totalShareAmount = 0,
}) {
  return {
    'paid_by': paidBy,
    'paid_for': paidFor,
    'share_amount': shareAmount,
    'total_expenses': totalExpenses,
    'total_share_amount': totalShareAmount,
    'paid_by_display_name': paidBy.split('@').first,
    'paid_by_paypal_me': null,
    'paid_by_iban': null,
    'paid_for_display_name': paidFor.split('@').first,
    'paid_for_paypal_me': null,
    'paid_for_iban': null,
  };
}

/// One row per member carrying that member's net balance
/// (positive = is owed money, negative = owes money).
Map<String, dynamic> balancesJson(Map<String, double> balances) {
  return {
    'group_shares_summary': [
      for (final entry in balances.entries)
        row(
          paidBy: entry.key,
          paidFor: entry.key,
          totalShareAmount: entry.value,
        ),
    ],
  };
}

Map<String, double> settle(Map<String, double> balances, {String currentUser = me}) {
  final group = Group();
  group.calculateGroupSharesSummarySimplified(balancesJson(balances), currentUser);
  return group.groupSharesSummary.map((email, summary) => MapEntry(email, summary.shareAmount));
}

void main() {
  group('calculateGroupSharesSummarySimplified', () {
    test('two members: I owe the full amount', () {
      final result = settle({me: -50.0, alice: 50.0});
      expect(result, {alice: -50.0});
    });

    test('two members: I am owed the full amount', () {
      final result = settle({me: 50.0, alice: -50.0});
      expect(result, {alice: 50.0});
    });

    test('three-way equal split: I owe both others', () {
      final result = settle({me: -66.66, alice: 33.33, bob: 33.33});
      expect(result.length, 2);
      expect(result[alice], -33.33);
      expect(result[bob], -33.33);
    });

    test('I am the creditor of two debtors', () {
      final result = settle({me: 60.0, alice: -40.0, bob: -20.0});
      expect(result[alice], 40.0);
      expect(result[bob], 20.0);
    });

    test('unequal 40/30/30 split', () {
      // alice paid 100, split 40 (me) / 30 (alice) / 30 (bob)
      final result = settle({me: -40.0, alice: 70.0, bob: -30.0});
      expect(result, {alice: -40.0});
    });

    test('settlements not involving me are not reported', () {
      final result = settle({me: 0.0, alice: -10.0, bob: 10.0});
      expect(result, isEmpty);
    });

    test('all balances zero settles to nothing', () {
      final result = settle({me: 0.0, alice: 0.0, bob: 0.0});
      expect(result, isEmpty);
    });

    test('unrounded thirds from the database are rounded on load', () {
      // 100 / 3 as raw doubles — must not produce settlements with
      // sub-cent amounts or hang the loop.
      final result = settle({
        me: -66.66666666666667,
        alice: 33.333333333333336,
        bob: 33.333333333333336,
      });
      for (final amount in result.values) {
        expect(amount, roundedToCents);
      }
      // I owe roughly a third to each; the unassignable leftover cent
      // must never inflate any single settlement.
      expect(result[alice]!.abs(), lessThanOrEqualTo(33.34));
      expect(result[bob]!.abs(), lessThanOrEqualTo(33.34));
    });

    test('four members with mixed balances settle fully', () {
      final result = settle({me: -30.0, alice: -20.0, bob: 10.0, carol: 40.0});
      // I owe 30 in total, split across creditors.
      final totalOwed = result.values.fold(0.0, (a, b) => a + b);
      expect(totalOwed, -30.0);
      for (final amount in result.values) {
        expect(amount, lessThan(0));
        expect(amount, roundedToCents);
      }
    });

    test('amounts differing by one cent', () {
      final result = settle({me: -0.01, alice: 0.01});
      expect(result, {alice: -0.01});
    });

    test('totalExpenses accumulates rounded across rows', () {
      final group = Group();
      group.calculateGroupSharesSummarySimplified({
        'group_shares_summary': [
          row(paidBy: alice, paidFor: me, totalExpenses: 0.1, totalShareAmount: -0.3),
          row(paidBy: bob, paidFor: me, totalExpenses: 0.2, totalShareAmount: -0.3),
          row(paidBy: me, paidFor: alice, totalShareAmount: 0.15),
          row(paidBy: me, paidFor: bob, totalShareAmount: 0.15),
        ],
      }, me);
      // 0.1 + 0.2 must be exactly 0.3, not 0.30000000000000004
      expect(group.totalExpenses, 0.3);
    });

    test('null and missing summary data yield empty results', () {
      final group = Group();
      group.calculateGroupSharesSummarySimplified({'group_shares_summary': null}, me);
      expect(group.groupSharesSummary, isEmpty);
      expect(group.totalExpenses, 0);
      expect(group.totalShareAmount, 0);
    });
  });

  group('calculateGroupSharesSummaryDefault', () {
    test('amounts I paid for others are positive (they owe me)', () {
      final group = Group();
      group.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: me, paidFor: alice, shareAmount: 25.0),
        ],
      }, me);
      expect(group.groupSharesSummary[alice]!.shareAmount, 25.0);
    });

    test('amounts others paid for me are negative (I owe them)', () {
      final group = Group();
      group.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: alice, paidFor: me, shareAmount: 25.0),
        ],
      }, me);
      expect(group.groupSharesSummary[alice]!.shareAmount, -25.0);
    });

    test('multiple rows accumulate without floating point drift', () {
      final group = Group();
      group.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: me, paidFor: alice, shareAmount: 0.1),
          row(paidBy: me, paidFor: alice, shareAmount: 0.2),
        ],
      }, me);
      expect(group.groupSharesSummary[alice]!.shareAmount, 0.3);
    });

    test('rows between other members are ignored', () {
      final group = Group();
      group.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: alice, paidFor: bob, shareAmount: 99.0),
        ],
      }, me);
      expect(group.groupSharesSummary, isEmpty);
    });

    test('paid_by and paid_for both me contributes only to totals', () {
      final group = Group();
      group.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: me, paidFor: me, shareAmount: 10.0, totalExpenses: 10.0, totalShareAmount: 0.0),
        ],
      }, me);
      expect(group.groupSharesSummary, isEmpty);
      expect(group.totalExpenses, 10.0);
    });
  });
}

/// Matcher: value is exactly representable at 2 decimal places.
final Matcher roundedToCents = predicate<double>(
  (v) => ((v * 100).roundToDouble() / 100 - v).abs() < 1e-9,
  'is rounded to whole cents',
);
