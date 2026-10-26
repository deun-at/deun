import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_draft.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'a@test.com';
const _b = 'b@test.com';

/// Two Itemized lines as the editor hands them over, one with an exact split
/// and existing claims so every field is set.
ExpenseDraft _draft() => ExpenseDraft(
  name: 'Supermarket',
  expenseDate: DateTime(2026, 10, 26),
  paidBy: _a,
  category: ExpenseCategory.food,
  entries: const [
    ExpenseEntryDraft(name: 'Beer', unitPrice: 5.0, quantity: 3),
    ExpenseEntryDraft(
      name: 'Wine',
      unitPrice: 8.5,
      splitMode: SplitMode.amount,
      shares: {_a, _b},
      shareData: {_a: 4.0, _b: 4.5},
      lockedMembers: {_a},
      existingClaims: [
        [_a],
      ],
    ),
  ],
);

void main() {
  group('ExpenseDraft.markEntriesClaimable', () {
    test('the draft it was called on is left unchanged', () {
      final draft = _draft();

      draft.markEntriesClaimable(notifyEmails: {_a, _b});

      expect(draft, _draft());
    });

    test('every other field is kept', () {
      final out = _draft().markEntriesClaimable();

      expect(
        out,
        ExpenseDraft(
          name: 'Supermarket',
          expenseDate: DateTime(2026, 10, 26),
          paidBy: _a,
          category: ExpenseCategory.food,
          entries: const [
            ExpenseEntryDraft(
              name: 'Beer',
              unitPrice: 5.0,
              quantity: 3,
              claimable: true,
            ),
            ExpenseEntryDraft(
              name: 'Wine',
              unitPrice: 8.5,
              splitMode: SplitMode.amount,
              shares: {_a, _b},
              shareData: {_a: 4.0, _b: 4.5},
              lockedMembers: {_a},
              claimable: true,
              existingClaims: [
                [_a],
              ],
            ),
          ],
        ),
      );
    });

    test('notify emails become every line\'s shares', () {
      final emails = {_a, _b, 'c@test.com'};

      final out = _draft().markEntriesClaimable(notifyEmails: emails);

      expect(out.entries.map((e) => e.shares), [emails, emails]);
    });

    test('without notify emails every line keeps its shares', () {
      final out = _draft().markEntriesClaimable();

      expect(out.entries.map((e) => e.shares), [
        <String>{},
        {_a, _b},
      ]);
    });

    test('a draft with no lines comes back with no lines', () {
      final draft = ExpenseDraft(
        name: 'Shop',
        expenseDate: DateTime(2026, 10, 26),
        entries: const [],
      );

      expect(draft.markEntriesClaimable(notifyEmails: {_a}), draft);
    });
  });
}
