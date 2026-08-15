# expense-delete-settled-guard — Warn before deleting an expense that a payback already touched

## Spec
- Source: idea (NOTES.md bug 3, Jakob 2026-07-24, branch `claude/group-management-issues-ifybxc`)
- Flight: —
- Goal: Stop silent balance surprises by naming, before the delete, what a deletion will reopen — without ever making an expense undeletable.

## Contract
- Acceptance:
  - Deleting an expense with `isPaidBackRow == true` shows a confirmation naming the counterparty and the settlement amount, and stating that the debt it settled will reopen. Cancelling performs **zero** writes.
  - Deleting a normal expense in a group that contains at least one payback row dated on or after that expense's `expenseDate` shows a confirmation stating that balances will shift because a settlement has already happened. Cancelling performs **zero** writes.
  - Deleting a normal expense in a group with no payback rows, or with paybacks dated strictly before it, keeps today's plain delete confirmation — no extra dialog, no regression.
  - Confirming a guarded delete performs exactly the same writes as today (`expense` delete, `expense_update_checker` delete, `update_group_member_shares`) in the same order. This feature adds **no** ledger semantics — the guard is presentation-level only.
  - The impact classifier is a pure function over `(expense, groupExpenses)` and is unit-tested at the date boundary: a payback dated the **same day** as the expense counts as covering it; a payback dated strictly **before** it does not.
  - Both delete call sites are guarded — the read view and the editor — proven by a widget test on each that cancelling leaves the expense present.
  - All new copy exists in EN and DE, and `flutter gen-l10n` output is committed.
- Provides:
  - `ExpenseDeletionImpact` — one of `none` · `reopensSettlement(counterparty: String, amount: double)` · `alreadySettled(paybackCount: int)`
  - `classifyExpenseDeletion(expense: Expense, groupExpenses: List<Expense>): ExpenseDeletionImpact` (pure)
- Consumes: —
- Decisions:
  - Guard scope -> both cases: the payback row itself **and** a normal expense already covered by a payback. (Jakob, prep 2026-08-15)
  - Behaviour -> warn then allow. Blocking was rejected: it would trap users behind a typo in an old expense.
  - Same-day paybacks count as covering the expense — `expenseDate` is a date, not a timestamp, so strict `>` would miss the common "settle up at the end of the night" case.
  - Detection reuses `Expense.isPaidBackRow` and the existing `classifyLedgerRow` vocabulary in `group_ledger.dart` rather than introducing a second notion of "is a settlement".
- Units:
  - Pure classifier: `ExpenseDeletionImpact` + `classifyExpenseDeletion`, unit-tested at the date boundary and on the empty-group case.
  - Dialog + copy: the two confirmation variants, EN + DE strings, generated l10n.
  - Wiring: both delete call sites route through the classifier; cancel path proven to write nothing.
- Blockers: —

## Approach
- `ExpenseRepository.delete` is an unguarded hard delete followed by a share recalculation, so today the only feedback is the balance moving afterwards. Keep it that way — do not add guard logic to the repository. The classifier reads the group's already-loaded expense list and drives the dialog; the repository call is unchanged, which keeps this feature cheap to revert and impossible to get wrong at the data layer.
- The expense list is already paginated (pageSize 20), so "the group's payback rows" must not be inferred from whatever page happens to be loaded. Either query the paybacks for the group explicitly or derive the flag from data the group detail already holds — decide against HEAD, but do not silently classify from a partial page.
- Likely touchpoints: lib/pages/expenses/presentation/expense_detail_read.dart (delete action), lib/pages/expenses/presentation/expense_detail.dart (delete action), lib/pages/groups/presentation/group_ledger.dart (existing row classification vocabulary), lib/pages/expenses/data/ (new classifier), lib/l10n/app_en.arb + app_de.arb.
- Depends: —
- Parallel-with: —

status: planned
