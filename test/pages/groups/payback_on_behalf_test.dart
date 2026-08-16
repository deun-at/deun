import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/payback_request.dart';
import 'package:deun/pages/groups/presentation/group_ledger.dart';
import 'package:deun/pages/groups/presentation/payment_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for payback-on-behalf's ledger effect and attribution.
///
/// No `Supabase.initialize`: the share summaries are computed by calling
/// `calculateGroupSharesSummaryDefault` with an explicit current-user email
/// instead of going through `loadDataFromJson`, exactly as
/// `test/pages/groups/settle_residue_test.dart` does.
const me = 'me@test.com';
const ann = 'ann@test.com';
const bob = 'bob@test.com';
const carol = 'carol@test.com';

const roster = [me, ann, bob, carol];

/// A `group_shares_summary` row exactly as `update_group_member_shares` emits
/// it: one row per (payer, member) pair. `total_share_amount` is the member's
/// net and is identical across every row that member appears in as `paid_for`.
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

/// Before: Ann paid 30.00, split evenly over Ann, Bob and Carol. Ann is owed 20,
/// Bob and Carol owe 10 each, and I (the recorder) am not involved at all.
List<Map<String, dynamic>> before() => [
  row(
    paidBy: ann,
    paidFor: ann,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: 20,
  ),
  row(
    paidBy: ann,
    paidFor: bob,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: -10,
  ),
  row(
    paidBy: ann,
    paidFor: carol,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: -10,
  ),
  row(paidBy: ann, paidFor: me, totalShareAmount: 0),
];

/// After: Bob paid Ann 10.00. `pay_back` writes ONE expense — paid_by = Bob,
/// is_paid_back_row = true, a single 10.00 entry shared 100% to Ann — and
/// `update_group_member_shares` recomputes. is_paid_back_row keeps the row out
/// of `total_expenses` (`case e.is_paid_back_row when false then ... else 0.0`)
/// while it still moves `share_amount` and the two nets.
///
/// This row set does not mention the recorder anywhere: the ledger effect of a
/// payback Bob recorded and one I recorded for him is the same by construction.
List<Map<String, dynamic>> after() => [
  row(
    paidBy: ann,
    paidFor: ann,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: 10,
  ),
  row(
    paidBy: ann,
    paidFor: bob,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: 0,
  ),
  row(
    paidBy: ann,
    paidFor: carol,
    shareAmount: 10,
    totalExpenses: 10,
    totalShareAmount: -10,
  ),
  row(paidBy: ann, paidFor: me, totalShareAmount: 0),
  row(paidBy: bob, paidFor: ann, shareAmount: 10, totalShareAmount: 10),
  row(paidBy: bob, paidFor: bob, totalShareAmount: 0),
  row(paidBy: bob, paidFor: carol, totalShareAmount: -10),
  row(paidBy: bob, paidFor: me, totalShareAmount: 0),
];

Group _seen(List<Map<String, dynamic>> rows, String viewer) {
  final g = Group();
  g.calculateGroupSharesSummaryDefault({'group_shares_summary': rows}, viewer);
  return g;
}

/// The FULL per-member balance map from [viewer]'s seat — every member of the
/// group, absent counterparties reading 0, so "unchanged" is asserted over the
/// whole roster and not just over the keys that happen to exist.
Map<String, double> _balances(List<Map<String, dynamic>> rows, String viewer) {
  final g = _seen(rows, viewer);
  return {
    for (final email in roster)
      if (email != viewer) email: g.groupSharesSummary[email]?.shareAmount ?? 0,
  };
}

/// A payback row as the ledger receives it once `pay_back` stamps the recorder.
Expense _paybackRow({String? recordedByEmail, String? recordedByDisplayName}) {
  final e = Expense();
  e.loadDataFromJson({
    'id': 'p1',
    'group_id': 'g1',
    'name': 'paid_back',
    'expense_date': '2026-08-16T10:00:00Z',
    'created_at': '2026-08-16T10:00:00Z',
    'paid_by': bob,
    'paid_by_display_name': 'bob',
    'is_paid_back_row': true,
    'category': null,
    'recorded_by_email': recordedByEmail,
    'recorded_by_display_name': recordedByDisplayName,
    'expense_entry': [
      {
        'id': 'pe1',
        'expense_id': 'p1',
        'name': null,
        'amount': 10,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2026-08-16T10:00:00Z',
        'item_group_id': null,
        'expense_entry_share': [
          {
            'expense_entry_id': 'pe1',
            'email': ann,
            'display_name': 'ann',
            'percentage': 100,
            'fixed_amount': null,
            'parts': null,
            'is_locked': false,
            'created_at': '2026-08-16T10:00:00Z',
          },
        ],
      },
    ],
  });
  return e;
}

void main() {
  group('recording "Bob paid Ann 10.00" moves exactly two balances', () {
    // 19 — criterion: X's balance moves by exactly the payback amount.
    test("the payer's balance with the payee closes by exactly the amount", () {
      expect(_balances(before(), bob)[ann], -10);
      expect(_balances(after(), bob)[ann], 0);
    });

    // 20 — criterion: Y's balance moves by exactly the payback amount.
    test("the payee's balance with the payer closes by exactly the amount", () {
      expect(_balances(before(), ann)[bob], 10);
      expect(_balances(after(), ann)[bob], 0);
    });

    // 21 — criterion: every other member's balance is unchanged, asserted over
    // the FULL groupSharesSummary map.
    test("an uninvolved member's whole balance map is identical", () {
      expect(_balances(after(), carol), _balances(before(), carol));
      expect(_balances(before(), carol), {me: 0.0, ann: -10.0, bob: 0.0});
      expect(
        _seen(after(), carol).totalShareAmount,
        _seen(before(), carol).totalShareAmount,
      );
    });

    // 22 — the recorder is a member too, and recording moves nothing of theirs.
    test("the recorder's own balances are untouched by what they recorded", () {
      expect(_balances(after(), me), _balances(before(), me));
      expect(_seen(after(), me).totalShareAmount, 0);
    });

    // 23 — criterion: same `is_paid_back_row` semantics as a self-payback.
    test('the payback is not counted as an expense on any seat', () {
      for (final viewer in roster) {
        expect(
          _seen(after(), viewer).totalExpenses,
          _seen(before(), viewer).totalExpenses,
          reason: viewer,
        );
      }
    });

    // 24 — criterion: indistinguishable from a payback the payer recorded.
    test('the ledger row is the same one whoever recorded it', () {
      final byBob = _paybackRow(
        recordedByEmail: bob,
        recordedByDisplayName: 'bob',
      );
      final byMe = _paybackRow(
        recordedByEmail: me,
        recordedByDisplayName: 'Me',
      );

      expect(classifyLedgerRow(byBob), LedgerRowType.payback);
      expect(classifyLedgerRow(byMe), LedgerRowType.payback);
      expect(byMe.paidBy, byBob.paidBy);
      expect(byMe.amount, byBob.amount);
      expect(byMe.isPaidBackRow, byBob.isPaidBackRow);
      expect(
        byMe.expenseEntries.values.single.expenseEntryShares.single.email,
        byBob.expenseEntries.values.single.expenseEntryShares.single.email,
      );
      // The ONLY difference is the attribution.
      expect(byBob.isRecordedOnBehalf, isFalse);
      expect(byMe.isRecordedOnBehalf, isTrue);
    });
  });

  group('Expense recorder attribution', () {
    // 25
    test('the recorder is read off the user_id embed', () {
      final e = _paybackRow(recordedByEmail: me, recordedByDisplayName: 'Me');

      expect(e.recordedByEmail, me);
      expect(e.recordedByDisplayName, 'Me');
    });

    // 26
    test('a payback the payer recorded themselves is not on behalf', () {
      expect(
        _paybackRow(
          recordedByEmail: bob,
          recordedByDisplayName: 'bob',
        ).isRecordedOnBehalf,
        isFalse,
      );
    });

    // 27 — rows written before the migration carry no recorder.
    test('a payback with no recorder shows no attribution', () {
      final e = _paybackRow();

      expect(e.recordedByEmail, isNull);
      expect(e.isRecordedOnBehalf, isFalse);
    });

    // 28 — a normal expense entered for someone else is NOT "on behalf".
    test(
      'a normal expense is never attributed, even with a different payer',
      () {
        final e = _paybackRow(recordedByEmail: me, recordedByDisplayName: 'Me');
        e.isPaidBackRow = false;

        expect(e.isRecordedOnBehalf, isFalse);
      },
    );

    // 29
    test('the select string asks the server for the recorder', () {
      expect(
        Expense.expenseSelectString,
        contains(
          '...user_id(recorded_by_email:email, '
          'recorded_by_display_name:display_name)',
        ),
      );
      // The lean payback probe select is deliberately untouched.
      expect(Expense.paybackSelectString, isNot(contains('recorded_by')));
    });
  });

  group('the settle-up surface agrees with the guard', () {
    /// Carol was soft-removed while settled, then an edit to an old expense of
    /// hers moved her balance again — the only way a removed member can end up
    /// outstanding.
    Group withRemovedCarol() {
      final g = Group();
      g.groupMembers = [
        _member(me, 'Me'),
        _member(ann, 'Ann'),
        _member(carol, 'Carol', removedAt: DateTime.utc(2026, 8, 15)),
      ];
      g.calculateGroupSharesSummaryDefault({
        'group_shares_summary': [
          row(paidBy: ann, paidFor: me, shareAmount: 10, totalShareAmount: -10),
          row(
            paidBy: carol,
            paidFor: me,
            shareAmount: 10,
            totalShareAmount: -10,
          ),
        ],
      }, me);
      return g;
    }

    // 47 — group-member-removal's criterion: the summary itself keeps them.
    test('the removed member still has a balance row in the summary', () {
      expect(withRemovedCarol().groupSharesSummary.keys, contains(carol));
      expect(withRemovedCarol().removedMemberEmails, {carol});
    });

    // 48 — but the payment screen must not offer a Pay button that can only
    // throw: `resolvePayback` rejects a soft-removed payee before any write.
    test('the payment screen offers no row for the removed member', () {
      final g = withRemovedCarol();
      final partition = PaymentPartition.fromSummary(
        g.groupSharesSummary,
        removedEmails: g.removedMemberEmails,
      );

      expect(partition.youPay.map((e) => e.email), [ann]);
      expect(
        resolvePayback(
          paidBy: me,
          paidFor: carol,
          amount: 10,
          recordedBy: me,
          members: g.groupMembers,
        ),
        isA<PaybackRejected>().having(
          (r) => r.reason,
          'reason',
          PaybackRejection.payeeNotInGroup,
        ),
      );
    });

    // 49 — the active counterparty is untouched by the filter.
    test('every active counterparty is still offered', () {
      final g = withRemovedCarol();

      expect(
        PaymentPartition.fromSummary(
          g.groupSharesSummary,
          removedEmails: g.removedMemberEmails,
        ).youPay.single.amount,
        10,
      );
      expect(
        resolvePayback(
          paidBy: me,
          paidFor: ann,
          amount: 10,
          recordedBy: me,
          members: g.groupMembers,
        ),
        isA<PaybackAccepted>(),
      );
    });
  });
}

GroupMember _member(String email, String displayName, {DateTime? removedAt}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = displayName;
  m.isGuest = false;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}
