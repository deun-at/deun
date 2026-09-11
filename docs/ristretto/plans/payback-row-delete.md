# payback-row-delete — Undoing a recorded payment

## Spec
- Source: idea (Jakob, 2026-09-11, found in the app while checking the rate prefill)
- Flight: —
- Goal: A payment recorded in error can be undone. Today a payback row is the only thing in the
  ledger that cannot be touched once written.

## Contract
- Acceptance:
  - [auto] A payback row in the group ledger is reachable — tapping it opens somewhere a delete can
    be issued from. It is inert today (`group_detail_list.dart:206` returns `_PaybackRow` outside
    the tap wrapping, and `_PaybackRow` is a bare `Container`).
  - [auto] Deleting one routes through the **existing** `classifyExpenseDeletion` branch and shows
    `ExpenseDeletionReopensSettlement` — the confirmation naming the counterparty and the amount.
    No second notion of "deleting a settlement" is introduced.
  - [auto] After the delete, the group balance and every member's share return to exactly their
    pre-payback values — the settlement is reopened, not merely hidden.
  - [auto] A payback recorded on someone else's behalf
    ([payback-on-behalf](archived/payback-on-behalf.md)) deletes by the same path, with no special
    case.
  - [human] On the live instance, deleting a payback row leaves `group_shares_summary` agreeing with
    the ledger — see the open question below, which is the whole risk of this feature.
  - [auto] `flutter analyze` and `flutter test` pass.
- Provides: —
- Consumes: `classifyExpenseDeletion`, `ExpenseDeletionReopensSettlement`, `probeDeletionImpact`,
  `expenseDeletePaybackTitle` (all from [expense-delete-settled-guard](archived/expense-delete-settled-guard.md));
  `ExpenseRepository.deleteExpense`
- Decisions:
  - **Delete, not a two-phase accept.** An accept/confirm flow taxes the common case — cash handed
    over between two people in the same room — with a pending state that stalls if the other person
    never opens the app, and leaves the balance misstating itself meanwhile. The app is trust-based
    everywhere else: anyone can already add, edit and delete an expense claiming you owe them
    anything. Paybacks being the single immutable row is inconsistent rather than safer, and it is
    the one row type where an error is guaranteed to matter, because it zeroes a balance.
  - **The confirmation is the friction, and it already exists.** `expense-delete-settled-guard`
    designed and built the wording for exactly this case.
  - Who may delete: the same rule as any expense, i.e. anyone in the group. Introducing a narrower
    permission here would be the only such rule in the app.
- Units:
  - Make the payback row reachable, and check whether the expense read view can render one at all —
    `ExpenseRepository`'s list queries filter `is_paid_back_row = false` in at least three places
    (`expense_repository.dart:25`, `:54`, `statistics_notifiers.dart:35`), so the detail route may
    never have been fed one. A small dedicated sheet may be cheaper than making the read view
    payback-aware; decide at pull time.
  - Wire the delete through the existing probe and confirmation.
  - Prove the balance returns to its pre-payback value.
- Manual-Checks: [manual-checks.md](../manual-checks.md) — confirm a deleted payback reopens the
  settlement in `group_shares_summary` on the live instance
- Blockers: —

## Approach
**Most of this feature already exists and is unreachable.** `classifyExpenseDeletion`
(`expense_deletion_impact.dart:84`) has a dedicated payback branch returning
`ExpenseDeletionImpact.reopensSettlement(counterparty, amount)`; `probeDeletionImpact` even
short-circuits the network round-trip for it; there is copy in both locales and there are unit tests
(`test/model/expense_deletion_impact_test.dart:80`, `:180`). None of it can be triggered, because no
UI path opens a payback row. That is the worst shape for dead code — it reads as covered ground.

So the work is mostly plumbing, and the one real unknown is the database. A payback row is written
by the `pay_back` RPC, while this would remove it with an ordinary row delete. Whether
`group_shares_summary` — a derived table on the self-hosted instance — reverses correctly on that
delete is **not verifiable from the build** and is the thing to establish first. If it does not, this
feature needs its own RPC and stops being small.

**Parked, deliberately not in scope.** `payback-on-behalf` lets person A assert that B paid C, where
neither B nor C acted and neither is told. That asymmetry deserves a notification to the two named
parties — "Jakob recorded that you paid Gast1 EUR 25" — with the row deletable from it. It is a
separate, smaller question than this one and should not be bundled: the fix here makes the row
deletable at all, which is the prerequisite either way.

- Likely touchpoints: `lib/pages/groups/presentation/group_detail_list.dart` (the inert
  `_PaybackRow`), `lib/pages/expenses/presentation/expense_detail_read.dart` or a new sheet,
  `lib/pages/expenses/data/expense_repository.dart`, both ARB files
- Depends: —
- Parallel-with: —

status: planned
