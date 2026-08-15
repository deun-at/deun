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
  - `ExpenseDeletionImpact` (`lib/pages/expenses/data/expense_deletion_impact.dart`) — sealed, one of `none` · `reopensSettlement(counterparty: String, amount: double)` · `alreadySettled(paybackCount: int)`
  - `classifyExpenseDeletion(Expense expense, List<Expense> groupExpenses): ExpenseDeletionImpact` (pure)
  - `probeDeletionImpact(Expense expense, {GroupPaybackLoader? loader}): Future<ExpenseDeletionImpact>` — the shared probe-fetch-classify sequence both delete call sites use; skips the network round-trip when the row is itself a payback, degrades to `none` on a failed probe
  - `localDayOf(String raw): DateTime` (`lib/helper/helper.dart`) — the local-midnight normalization factored out of the ledger's day grouping so the guard's "same day" matches the ledger's
  - `HeaderIconButton`'s new `loading` bool param (`lib/widgets/restyle/deun_header.dart`) — shows a small spinner in place of the icon and ignores taps while a probe is in flight
  - `Expense.paybackSelectString` (`lib/pages/expenses/data/expense_model.dart`) — the trimmed select for payback rows
  - `ExpenseRepository.fetchPaybackRows(String groupId): Future<List<Expense>>` — every payback row of a group, on the trimmed select
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

status: done

## Evidence
- Confirmation naming counterparty + amount, cancel = zero writes: `test/model/expense_deletion_impact_test.dart` (`classifyExpenseDeletion` group — "deleting a payback row reports the counterparty and the amount") + `test/widgets/expense_detail_read_test.dart` / `test/widgets/expense_editor_delete_guard_test.dart` ("deleting a payback row never probes the group").
- Already-settled normal expense shows the balances-will-shift confirmation: `expense_deletion_impact_test.dart` — "paybackCount counts only the covering paybacks", "normal expenses in the list are never mistaken for settlements".
- No-payback / paybacks-strictly-before keeps today's plain confirmation: `expense_deletion_impact_test.dart` — "an expense in a group with no other rows at all is unguarded", "a payback dated strictly BEFORE the expense does not cover it"; both widget test files — "an unguarded delete shows today plain confirmation".
- Same-day boundary: `expense_deletion_impact_test.dart` — "a payback dated the SAME day counts as covering the expense" vs "a payback dated strictly BEFORE the expense does not cover it" (12 tests total in this file, including the copy/l10n group).
- Confirming performs the same writes in the same order, unchanged: proven by construction — `ExpenseRepository.delete` is untouched by this feature (verified against `lib/pages/expenses/data/expense_repository.dart`); both call sites still call it as their only write.
- Both call sites guarded, cancel leaves the expense present: `expense_detail_read_test.dart` and `expense_editor_delete_guard_test.dart`, each with its own "unguarded delete shows today plain confirmation" / guarded-delete / never-probes-on-payback tests (5 `testWidgets` added to the editor file).
- EN/DE copy + generated l10n committed: `expense_deletion_impact_test.dart` — "all new copy exists in German and differs from English"; `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, and the three generated `app_localizations*.dart` files are part of this commit.
- Gate summary: `flutter analyze` — no issues found. `flutter test` — 1012 passed, 0 failed.
- Review verdict: round 1 found 1 bug + 6 lean findings, all fixed. Round 2 found 1 bug (a vacuous test assertion targeting the wrong button) + 1 lean finding, both fixed. Round 3 escalated the remaining fix, proved it red without the guard and green with it, and closed with `review: clean`.
