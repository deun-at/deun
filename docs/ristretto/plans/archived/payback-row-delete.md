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
    ([payback-on-behalf](payback-on-behalf.md)) deletes by the same path, with no special
    case.
  - [human] On the live instance, deleting a payback row leaves `group_shares_summary` agreeing with
    the ledger — see the open question below, which is the whole risk of this feature.
  - [auto] `flutter analyze` and `flutter test` pass.
- Provides:
  - `paybackCounterpartyShare(Expense expense) → ExpenseEntryShare?` and
    `paybackSummaryLine(Expense expense, AppLocalizations l10n, {required String currencyCode, String? currentUserEmail}) → String`
    (`lib/pages/groups/presentation/group_ledger.dart`) — the one derivation of "which share a
    payback settles" and the "{payer} paid back {amount} to {payee}" sentence built from it.
  - `showPaybackDetailSheet(BuildContext context, {required Group group, required Expense expense, ExpenseDeleter? deleteExpense}) → Future<void>`,
    `PaybackDetailSheet`, and the `ExpenseDeleter` typedef
    (`lib/pages/groups/presentation/payback_detail_sheet.dart`) — the read/undo surface for one
    payback row.
- Consumes: `classifyExpenseDeletion`, `ExpenseDeletionReopensSettlement`, `probeDeletionImpact`,
  `expenseDeletePaybackTitle` (all from [expense-delete-settled-guard](expense-delete-settled-guard.md));
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
- Manual-Checks: [manual-checks.md](../../manual-checks.md) — confirm a deleted payback reopens the
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

## Evidence

Gate green: `flutter analyze` — "No issues found!"; `flutter test` — 1596 tests pass, none failing
(1590 baseline recorded in the build plan + 6 new). `dart format` run on the touched files only
(`group_detail_list.dart`, `group_ledger.dart`, `payback_detail_sheet.dart`,
`group_detail_ledger_test.dart`, `payback_detail_sheet_test.dart`) — the wider tree still carries
the pre-existing unformatted files recorded by `save-status-rollout`.

review: notes-only · rounds: 1 · open: 0 block, 1 note, 3 lean
tier: normal

The first implementer attempt at this feature died mid-work. A second implementer ran fresh,
reconciled the partial tree it inherited against this build plan unit by unit, and verified all of
it as its own before handing off to review.

Per-criterion proof:
- **Criterion 1** (the row is reachable) — `test/widgets/group_detail_ledger_test.dart`: "tapping a
  payback row opens the payback detail sheet" taps the PAYMENT chip, finds `PaybackDetailSheet` and
  its delete key, and asserts the sheet restates the same sentence the row shows
  (`findsNWidgets(2)`), proving `paybackSummaryLine` is the one derivation for both.
- **Criterion 2** (routes through the existing `classifyExpenseDeletion` branch /
  `ExpenseDeletionReopensSettlement`) — `payback_detail_sheet_test.dart`: "deleting names the
  counterparty and the amount, in the existing settlement copy" asserts
  `expenseDeletePaybackTitle`/`expenseDeletePaybackMessage` render and the item/settled-guard
  titles do not; "cancelling the confirmation deletes nothing" asserts zero calls. No new ARB key
  is introduced anywhere in the feature, which is itself the proof that no second notion of
  "deleting a settlement" exists.
- **Criterion 3** (balance and every share return to their pre-payback values) — **proven by
  proxy, not directly.** "confirming hard-deletes the payback row through the shared expense
  delete" and its failure-path sibling observe only that `ExpenseRepository.delete(expenseId,
  groupId)` — the same shared deleter every other expense delete in the app runs through — is
  called exactly once, with the payback's own id and group. No test computes or reads back a
  balance or a share. That call is known, from the build plan's findings rather than from a test,
  to land on a function whose third statement is `update_group_member_shares`, the full
  `group_shares_summary` recompute — so the client-side half of "reopened, not merely hidden" is
  exercised; the live-instance half, whether that recompute actually reverses the row, is the
  `[human]` manual check above, and it stays open. Per the reviewer's note (below), the `[auto]`
  label on this criterion's proof is optimistic about what the test shows, even though the shipped
  behaviour — the call demonstrably reaching `ExpenseRepository.delete` — is correct.
- **Criterion 4** (on-behalf payback, no special case) — "a payback recorded on someone else
  behalf deletes by the same path" pumps a payback with `recordedByEmail`/`recordedByDisplayName`
  set, asserts the attribution line renders, and drives the identical delete path to the same
  single call and success snackbar — no branch in `_confirmDelete` or `ExpenseRepository.delete`
  looks at who recorded it.
- **Criterion 5** (gates) — `flutter analyze` clean, `flutter test` 1596/1596 passing.
- The **`[human]` criterion** is `pending human`, per the entry appended to
  `docs/ristretto/manual-checks.md` — not proven by anything in this run.

Process note from the reviewer, worth recording but not a finding: `supabase/config.toml` is a
stock Supabase CLI local-dev config (db on port 54322), so a local Postgres with
`supabase/migrations/` applied is arguably an in-repo path to `group_shares_summary`; it is
referenced nowhere in `docs/`, needs Docker, and `manual-checks.md`'s standing preamble declares
the instance out of reach project-wide — so this feature followed convention. Worth deciding once
for the file, not per feature.

## Open findings

Left open by review round 1 (`notes-only`), recorded verbatim, none fixed:

note · test/widgets/payback_detail_sheet_test.dart:219 · Criterion 3 is marked `[auto]` but no auto
test computes or observes a balance or a share — the whole proof is `deleted.calls == 1` with
`('p1','g1')`, i.e. "the shared deleter was called"; the actual settlement-reopening is the
`[human]` walk. Cannot harm a user: the call demonstrably lands on `ExpenseRepository.delete`,
whose third statement is the full `group_shares_summary` recompute, so the shipped behaviour is
right and only the `[auto]` label on the proof is optimistic · fix: say so in the close Evidence
(proof by proxy, live half deferred to the manual check) rather than letting criterion 3 read as
test-proven.

lean · lib/pages/groups/presentation/group_ledger.dart:73 · `paybackCounterpartyShare` is a
byte-for-byte re-derivation of `_paybackCounterparty`
(`lib/pages/expenses/data/expense_deletion_impact.dart:140`) — same nested loop over
`expenseEntries.values` / `expenseEntryShares` returning the first hit; two files now own "which
share a payback settles" · fix: put the share helper in `expenses/data/` (presentation may import
data, not the reverse) and make `_paybackCounterparty`
`paybackCounterpartyShare(expense)?.displayName ?? ''`.

lean · lib/pages/groups/presentation/payback_detail_sheet.dart:34 · `showPaybackDetailSheet`'s
`ExpenseDeleter? deleteExpense` is passed by nobody — the only production caller omits it and
every test constructs `PaybackDetailSheet` directly (grep over `lib/` + `test/` finds one hit, the
widget field). Unlike its model `showRecordPaybackSheet`, whose param is exercised at
`test/widgets/record_payback_sheet_test.dart:378` · fix: drop the parameter from the show
function, or use it in one test so the seam is real.

lean · test/widgets/payback_detail_sheet_test.dart:230 · The on-behalf test re-runs criterion 3's
entire assertion set (`calls`, `expenseId`, `groupId`, success snackbar) on top of what is
distinctive to criterion 4 (the `paybackRecordedBy` line and the *same* confirmation title); the
cancel test likewise re-asserts `calls == 0`, which the first test already establishes with the
confirmation open · fix: keep the distinctive assertions, drop the re-proof of the shared path.

status: done
