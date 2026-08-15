import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:deun/pages/groups/presentation/group_list_view_model.dart';
import 'package:deun/pages/groups/presentation/payment_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for settle-residue. Every assertion restates a criterion
/// from `docs/ristretto/plans/settle-residue.md`.
///
/// No `Supabase.initialize`: every function under test is pure, and the share
/// summaries are computed by calling `calculateGroupSharesSummary*` with an
/// explicit current-user email instead of going through `loadDataFromJson`.
const me = 'me@test.com';
const alice = 'alice@test.com';
const bob = 'bob@test.com';

/// A `group_shares_summary` row exactly as `update_group_member_shares` emits
/// it: one row per (payer, member) pair, every amount UNROUNDED
/// (`ee.amount * (ees.percentage / 100)` has no rounding at any step).
Map<String, dynamic> row({
  required String paidBy,
  required String paidFor,
  double shareAmount = 0,
  double totalExpenses = 0,
  double totalShareAmount = 0,
}) => {
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

/// Thirds as the database stores them: percentages are kept at full double
/// precision (`100 / shareData.length`), so each share is a non-cent value.
/// [twoThirds] is the identical double whether you reach it as 20.00 split three
/// ways (`20 * (100 / 3) / 100`) or as two 10.00 thirds summed by the server's
/// `total_share_amount` subquery — which is why one constant serves both.
const thirdOfTen = 3.3333333333333335;
const twoThirds = 6.666666666666667;

Group _defaultGroup(List<Map<String, dynamic>> rows, {String user = me}) {
  final g = Group();
  g.calculateGroupSharesSummaryDefault({'group_shares_summary': rows}, user);
  return g;
}

/// A bare [Group] carrying only what the list view model reads (mirrors the
/// helper in `test/model/group_list_view_model_test.dart`).
Group _balanceGroup(double totalShareAmount, {String name = 'Trip'}) {
  final g = Group();
  g.id = 'g1';
  g.name = name;
  g.colorValue = 0xFF5750E6;
  g.simplifiedExpenses = false;
  g.createdAt = '';
  g.userId = null;
  g.currencyCode = 'EUR';
  g.groupMembers = [];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = totalShareAmount;
  g.expenses = null;
  return g;
}

GroupSharesSummary _summary(double shareAmount) {
  final s = GroupSharesSummary();
  s.displayName = 'Alice';
  s.paypalMe = null;
  s.iban = null;
  s.shareAmount = shareAmount;
  return s;
}

void main() {
  group('the reported remainder (2026-08-11)', () {
    // Alice paid 10.00 split three ways (her row for me) and I paid 20.00 split
    // three ways (my row for her). Row order matches the server's
    // `order by e.paid_by, gm.email`.
    List<Map<String, dynamic>> reportedRows() => [
      row(
        paidBy: alice,
        paidFor: me,
        shareAmount: thirdOfTen,
        totalExpenses: thirdOfTen,
        totalShareAmount: thirdOfTen,
      ),
      row(paidBy: me, paidFor: alice, shareAmount: twoThirds),
    ];

    // 1
    test('the pairwise balance is the unrounded sum rounded ONCE', () {
      final g = _defaultGroup(reportedRows());

      // Pre-fix this is 3.34: roundCurrency ran after each accumulation, so
      // -3.33 + 6.666666666666667 rounded up instead of 3.3333333333333335
      // rounding down.
      expect(g.groupSharesSummary[alice]!.shareAmount, 3.33);
    });

    // 2
    test(
      'the pairwise row and the group total agree before any settlement',
      () {
        final g = _defaultGroup(reportedRows());

        expect(g.groupSharesSummary[alice]!.shareAmount, g.totalShareAmount);
      },
    );

    // 3
    test('settling that balance leaves nothing the app calls outstanding', () {
      final g = _defaultGroup(reportedRows());
      final settled = g.groupSharesSummary[alice]!.shareAmount;

      // What `update_group_member_shares` will recompute after the payback:
      // the exact balance minus what was paid.
      final residue = thirdOfTen - settled;

      // Pre-fix: settled == 3.34, residue == -0.006666666666666643, which
      // renders as -0.01 — the "person I paid back owes me 0.01" report.
      expect(isSettled(residue), isTrue);
      expect(roundCurrency(residue), 0.0);
    });
  });

  group('one rounding rule for every accumulated figure', () {
    // 4
    test('totalExpenses accumulates raw and rounds once', () {
      final g = _defaultGroup([
        row(paidBy: alice, paidFor: me, totalExpenses: thirdOfTen),
        row(paidBy: bob, paidFor: me, totalExpenses: thirdOfTen),
        row(paidBy: me, paidFor: me, totalExpenses: thirdOfTen),
      ]);

      // 3 * 3.3333333333333335 == 10.000000000000002 → 10.00. Rounding each row
      // first would have produced 9.99.
      expect(g.totalExpenses, 10.0);
    });

    // 5
    test('a pair whose two directions cancel nets exactly zero', () {
      final g = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: thirdOfTen),
        row(paidBy: me, paidFor: alice, shareAmount: thirdOfTen),
      ]);

      expect(g.groupSharesSummary[alice]!.shareAmount, 0.0);
      expect(isSettled(g.groupSharesSummary[alice]!.shareAmount), isTrue);
    });

    // 6
    test('simplified mode rounds totalExpenses once too', () {
      final g = Group();
      g.calculateGroupSharesSummarySimplified({
        'group_shares_summary': [
          row(
            paidBy: alice,
            paidFor: me,
            totalExpenses: thirdOfTen,
            totalShareAmount: -thirdOfTen,
          ),
          row(
            paidBy: bob,
            paidFor: me,
            totalExpenses: thirdOfTen,
            totalShareAmount: -thirdOfTen,
          ),
          row(paidBy: me, paidFor: alice, totalShareAmount: thirdOfTen),
          row(paidBy: me, paidFor: bob, totalShareAmount: thirdOfTen),
        ],
      }, me);

      expect(g.totalExpenses, 6.67);
    });
  });

  group('Group.amountToSettleWith', () {
    // 7
    test('is exactly what the payment screen shows for the same pair', () {
      final g = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: thirdOfTen),
      ]);
      final partition = PaymentPartition.fromSummary(g.groupSharesSummary);

      expect(g.amountToSettleWith(alice), partition.youPay.single.amount);
      expect(g.amountToSettleWith(alice), 3.33);
    });

    // 8
    test('a settled pair settles nothing, on either path', () {
      final g = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: 0.004),
      ]);

      expect(g.amountToSettleWith(alice), isNull);
      expect(
        PaymentPartition.fromSummary(g.groupSharesSummary).isEmpty,
        isTrue,
      );
    });

    // 9
    test('a half-cent debt is offered by the payment screen AND payBackAll', () {
      // Pre-fix these disagreed: the payment screen offered anything from 0.005
      // up, while payBackAll only settled from 0.01 up.
      final g = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: 0.005),
      ]);

      expect(g.amountToSettleWith(alice), 0.01);
      expect(
        PaymentPartition.fromSummary(g.groupSharesSummary).youPay.single.amount,
        0.01,
      );
    });

    // 10
    test(
      'nothing to settle when they owe you, or when they are not a pair',
      () {
        final g = _defaultGroup([
          row(paidBy: me, paidFor: alice, shareAmount: 12.5),
        ]);

        expect(g.amountToSettleWith(alice), isNull);
        expect(g.amountToSettleWith(bob), isNull);
      },
    );
  });

  group('one predicate, every surface', () {
    // 11
    test('a 0.007 balance is outstanding on every surface at once', () {
      const residue = 0.007;

      // Payment screen (was 0.005 → outstanding).
      final partition = PaymentPartition.fromSummary({
        alice: _summary(-residue),
      });
      expect(partition.youPay.single.amount, closeTo(residue, 1e-12));

      // Group list hero (was 0.01 → contributed nothing).
      final agg = aggregateOverallBalance([_balanceGroup(-residue)]);
      expect(agg.owe, 0.01);

      // Sort tiers: the 0.007 group ranks UNSETTLED, so it sorts ahead of a
      // truly settled group even though its name sorts later. Pre-fix both were
      // in the settled tier and the name decided.
      final sorted = sortGroups([
        _balanceGroup(0, name: 'Alpha'),
        _balanceGroup(-residue, name: 'Zeta'),
      ], isFavorite: (_) => false);
      expect(sorted.map((g) => g.name), ['Zeta', 'Alpha']);

      // Friend list normalization (was 0.01 → zeroed) and the member-removal
      // guard, both now the same question.
      expect(isSettled(residue), isFalse);
      expect(
        resolveMemberRemoval(balance: residue, hasExpenseHistory: true),
        isA<MemberRemovalBlocked>(),
      );
    });

    // 12
    test('a 0.004 balance is settled on every surface at once', () {
      const residue = 0.004;

      expect(
        PaymentPartition.fromSummary({alice: _summary(-residue)}).isEmpty,
        isTrue,
      );
      expect(aggregateOverallBalance([_balanceGroup(-residue)]).owe, 0);
      expect(isSettled(residue), isTrue);
      expect(
        resolveMemberRemoval(balance: residue, hasExpenseHistory: true),
        MemberRemovalOutcome.softRemoved,
      );
    });
  });

  group('both group modes and payBackAll', () {
    // 13
    test(
      'default mode: a 10.00 three-way split settles every pairwise balance',
      () {
        // I paid 10.00 split three ways: each debtor owes 3.3333…
        final g = _defaultGroup([
          row(paidBy: me, paidFor: alice, shareAmount: thirdOfTen),
          row(paidBy: me, paidFor: bob, shareAmount: thirdOfTen),
          row(
            paidBy: me,
            paidFor: me,
            shareAmount: thirdOfTen,
            totalShareAmount: twoThirds,
          ),
        ], user: me);

        for (final email in [alice, bob]) {
          final settled = g.groupSharesSummary[email]!.shareAmount;
          expect(settled, 3.33);
          // What each debtor's own balance becomes once they settle it.
          expect(isSettled(thirdOfTen - settled), isTrue);
        }

        // [deferred] The PAYER's net after both settle is
        // 6.666666666666667 - 6.66 = 0.0066666…, which is NOT settled: two
        // sub-cent residues add up. Only `pay_back_exact` (Unit 2, deferred to
        // MANUAL_OPS) settles the exact value and drives this to a hard zero.
        // Asserted here as the pre-migration truth so the gap stays visible.
        expect(isSettled(twoThirds - 6.66), isFalse);
      },
    );

    // 14
    test('simplified mode: assignments are cent-exact and settle clean', () {
      // Same 10.00 three-way split, expressed as the nets simplified mode reads.
      final g = Group();
      g.calculateGroupSharesSummarySimplified({
        'group_shares_summary': [
          row(paidBy: me, paidFor: me, totalShareAmount: twoThirds),
          row(paidBy: me, paidFor: alice, totalShareAmount: -thirdOfTen),
          row(paidBy: me, paidFor: bob, totalShareAmount: -thirdOfTen),
        ],
      }, alice);

      // Alice owes her third to me, as a whole number of cents.
      final owed = g.groupSharesSummary[me]!.shareAmount;
      expect(owed, -3.33);
      expect(roundCurrency(owed), owed);
      expect(isSettled(thirdOfTen - owed.abs()), isTrue);
    });

    // 15
    test('payBackAll settles the same amount the payment screen offers', () {
      // payBackAll maps each active group through amountToSettleWith; a group
      // where the friend owes the user, and a settled group, are both skipped.
      final owing = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: twoThirds),
      ]);
      final owed = _defaultGroup([
        row(paidBy: me, paidFor: alice, shareAmount: twoThirds),
      ]);
      final settledGroup = _defaultGroup([
        row(paidBy: alice, paidFor: me, shareAmount: 0.004),
      ]);

      expect(owing.amountToSettleWith(alice), 6.67);
      expect(
        PaymentPartition.fromSummary(
          owing.groupSharesSummary,
        ).youPay.single.amount,
        6.67,
      );
      expect(owed.amountToSettleWith(alice), isNull);
      expect(settledGroup.amountToSettleWith(alice), isNull);
    });
  });
}
