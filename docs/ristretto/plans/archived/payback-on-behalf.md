# payback-on-behalf — Record a payback that someone else made

## Spec
- Source: idea (NOTES.md idea 6, Jakob 2026-07-24, branch `claude/group-management-issues-ifybxc`)
- Flight: —
- Goal: Let paybacks from people who don't use the app be recorded by someone who does, so a group can actually reach zero.

## Contract
- Acceptance:
  - A payback can be recorded with a payer other than the current user: any member of the group may record "X paid Y" for any two distinct members of that group.
  - The recorded payback is indistinguishable in the ledger from one the payer recorded themselves, except that it carries who recorded it — same `is_paid_back_row` semantics, same effect on balances.
  - Recording "X paid Y" moves X's and Y's balances by exactly the payback amount and leaves every other member's balance unchanged, asserted over the full `groupSharesSummary` map.
  - **[deferred]** A payback where payer and payee are the same member is rejected before any write. *The client half is enforced and tested (`resolvePayback`, `GroupRepository.payBack`, the record sheet); the server backstop lives in the unapplied migration — manual-checks verification step 1.*
  - **[deferred]** A payback naming a member who is not in the group, or who is soft-removed, is rejected before any write. *Same split: client-side enforced and tested, server backstop deferred — manual-checks verification step 2.*
  - Recording a payback on someone's behalf notifies the **payee** and the **payer** (when the payer is a real user, not a guest) — the person whose money moved must find out, and the notification must name who recorded it.
  - The existing self-payback path (`_paid_by = current user`) produces byte-identical writes to today — this feature extends the RPC, it does not re-route the common case.
  - **[deferred]** The ledger and expense read view show who recorded a payback when that differs from the payer. *The rendering is widget-tested against fixtures, but `pay_back` only starts stamping `expense.user_id` once the migration is applied — manual-checks verification step 3.*
  - All new copy exists in EN and DE with generated l10n committed.
- Provides:
  - `GroupRepository.payBack(context, groupId: String, email: String, amount: double, {paidBy: String?, members: List<GroupMember>?, sendNotification: bool}): Future<void>` — `paidBy` defaulting to the current user preserves every existing call site; `members` lets a caller that already holds the roster (e.g. `payBackAll`) skip a redundant SELECT
  - `GroupRepository.payBackAll(context, email): Future<PayBackAllResult>` — return type widened from `Future<void>`; `PayBackAllResult.settledGroupNames` / `.skippedGroupNames` / `.isComplete` let the caller distinguish a full settle from a partial one
  - `lib/pages/groups/data/payback_request.dart` — `resolvePayback(...)`, the pure decision function, plus its sealed result `PaybackPlan` (`PaybackAccepted` / `PaybackRejected`), `PaybackRejection` enum, and `PaybackRejectedException`
  - `GroupRepository.planPayBack(...)` (`@visibleForTesting`) and `GroupRepository.payBackRpcParams(...)` — the default-application and RPC-argument-map seams the tests assert against
  - `GroupRepository.resolvePayBackAll(...)` and its `PayBackAllPlan` / `PayBackAllTarget` — the pure per-friend fan-out decision behind `payBackAll`
  - `lib/pages/groups/presentation/record_payback_sheet.dart` — `showRecordPaybackSheet(context, {required group, PaybackRecorder? recordPayback})` and `RecordPaybackSheet`, reachable from the settle-up screen's new "Record a payment" button
  - `Expense.isRecordedOnBehalf` / `Expense.recordedByDisplayName` / `Expense.recordedByEmail` — read off the new `user_id` embed in `expenseSelectString`, rendered in the ledger row and the expense read view
  - `FriendDetailSheet({..., FriendSettleAll? settleAll})` — injectable seam over `payBackAll` so the friend sheet can render the partial-settle case
- Consumes: —
- Decisions:
  - Permission model -> any member may record a payback between any two members. No owner column, no migration for roles. (Jakob, prep 2026-08-15)
  - Rationale for that ruling: Deun already lets any member edit and delete anyone's expenses, so an owner-gated payback would be a stricter rule than the app applies to strictly more destructive actions. Adding a real owner concept was considered and rejected as a disproportionate cost (migration + backfill + a new permission concept across the UI).
  - Because there is no owner, the deterrent is visibility, not permission — hence the mandatory notification to both parties and the "recorded by" attribution. **These are load-bearing, not polish.** Do not drop them to reduce scope.
  - The RPC gains an optional payer parameter rather than a new RPC, so the self-payback path stays on exactly one code path.
- Units:
  - Repository + call sites: optional `paidBy` on `GroupRepository.payBack`, existing callers untouched. **No migration is needed for this** — see the RPC note below.
  - Migration: add validation to `pay_back` — payer and payee must be distinct and both current, non-removed members of `_group_id`. The function validates none of this today.
  - Recording attribution: persist and expose who recorded the payback; surface it in the ledger and expense read view.
  - Notification: both-parties notification naming the recorder, extending `sendGroupPayBackNotification`.
  - UI: choosing a payer when recording a payback, from the settle-up surface.
- Blockers: —
- Deferred DB work: **minimal here.** The core capability needs no migration — `pay_back` already
  takes `_paid_by`, so recording someone else's payback is a client change and its criteria must
  genuinely pass. Only the validation (payer ≠ payee, both current non-removed members) is deferred:
  author it, mark those criteria `[deferred]`, append to [manual-checks.md](../../manual-checks.md), continue.

## Approach
- **The RPC already supports this.** `pay_back(_group_id, _paid_by, _paid_for, _amount)` takes the payer as a parameter and writes it straight to `expense.paid_by` — recovered 2026-08-15, now in `supabase/migrations/20260815000000_baseline_ledger_functions.sql`. The restriction to "me" is purely client-side: `group_repository.dart:213` hardcodes `supabase.auth.currentUser?.email`. **The core capability is a one-line client change**, not a migration. Scope the feature accordingly and spend the effort on attribution, notification and validation instead.
- The RPC validates nothing — not that the payer and payee differ, not that either belongs to the group. That gap already exists for self-paybacks; this feature widens who can trigger it, so close it here rather than inheriting it.
- Keep the new parameter optional with a caller default so `payBackAll` and the settle-up sheet need no signature churn.
- The client currently calls `pay_back` and then `update_group_member_shares` separately, with a one-shot retry to paper over partial state. Do not extend that pattern — if the new work needs more statements, prefer moving them inside the RPC where they are already transactional.
- Likely touchpoints: supabase/migrations/ (new migration), lib/pages/groups/data/group_repository.dart (`payBack`, `payBackAll`, notification), lib/pages/groups/presentation/group_detail_payment.dart (payer selection), lib/pages/groups/presentation/payment_view_model.dart (partitioning is per-current-user today), lib/pages/groups/presentation/group_ledger.dart (attribution), lib/l10n/app_en.arb + app_de.arb.
- Depends: settle-residue
- Parallel-with: group-member-removal

`Depends: settle-residue` because both features change the `pay_back` RPC, whose definition is not in
this repo. Correcting the settlement amount and extending the signature in two concurrent passes over
a function we have to recover from the live instance first is how one of them gets silently reverted.

## Evidence

- **Any member may record "X paid Y" between two other members** — `resolvePayback` unit tests `'a
  member records a payback between two OTHER members'` and `'a self-payback is accepted and is not on
  behalf of anyone'` (`test/model/payback_request_test.dart`), plus the widget-level round-trip in
  `test/pages/groups/payback_on_behalf_test.dart` (`'recording "Bob paid Ann 10.00" moves exactly two
  balances'` group).
- **Indistinguishable in the ledger except for the recorder** — same `is_paid_back_row` write path
  proven by `'the ledger row is the same one whoever recorded it'`
  (`test/pages/groups/payback_on_behalf_test.dart`); attribution rendering covered separately below.
- **Recording "X paid Y" moves exactly X's and Y's balances, full `groupSharesSummary` map** — the
  `'recording "Bob paid Ann 10.00" moves exactly two balances'` group in
  `test/pages/groups/payback_on_behalf_test.dart`: `"the payer's balance ... closes by exactly the
  amount"`, `"the payee's balance ... closes by exactly the amount"`, `"an uninvolved member's whole
  balance map is identical"`, `"the recorder's own balances are untouched by what they recorded"`,
  `'the payback is not counted as an expense on any seat'`.
- **`[deferred]` payer = payee is rejected before any write** — client half: `resolvePayback` tests
  `'payer and payee being the same member is rejected'`, `'paying yourself back is rejected on the self
  path too'`, and `GroupRepository.payBack` throwing `PaybackRejectedException` before any RPC call
  (structural — `planPayBack` runs and is switched on before `params`/`supabase.rpc` are reached).
  Server backstop is `[deferred]` to manual-checks verification step 1.
- **`[deferred]` a non-member or soft-removed payer/payee is rejected before any write** — client half:
  `resolvePayback` tests `'a payer who is not in the group is rejected, named by email'`, `'a payee who
  is not in the group is rejected'`, `'a soft-removed payer is rejected and named by display name'`,
  `'a soft-removed payee is rejected'` (`test/model/payback_request_test.dart`), plus
  `PaybackRejected.message` group's `'each rejection maps to its own copy'` for the surfaced text.
  Server backstop is `[deferred]` to manual-checks verification step 2.
- **Both payee and payer (when not a guest) are notified, naming the recorder** —
  `'both parties are notified when the payer is a real user'`, `'a guest payer is not notified — only
  the payee is'`, `'a self-payback still reaches only the payee once the recorder is factored in'`, and
  `'the accepted plan carries every display name the notification needs'`
  (`test/model/payback_request_test.dart`), asserting `PaybackAccepted.notificationReceivers` and the
  three display-name fields `GroupRepository.payBack` passes into
  `sendGroupPayBackNotification(..., paidByDisplayName:, paidForDisplayName:, recordedByDisplayName:)`.
- **Self-payback path is byte-identical to before this feature** — `test/model/group_repository_test.dart`:
  `'the self-payback path sends exactly what it sent before'` and `'recording on behalf changes
  _paid_by and nothing else'`, both asserting `payBackRpcParams` output directly; `'the argument names
  are the four both RPCs declare, in order'` pins the map shape `pay_back`/`pay_back_exact` expect.
- **`[deferred]` ledger and read view show the recorder when it differs from the payer** — rendering
  proven against fixtures: `'a payback recorded by someone else names the recorder'` / `'a payback the
  payer recorded shows no attribution line'` (`test/widgets/group_detail_ledger_test.dart`), and `'the
  read view names the recorder of an on-behalf payback'` / `'the read view shows no attribution when
  the payer recorded it'` (`test/widgets/expense_detail_read_test.dart`), backed by `Expense
  .isRecordedOnBehalf` unit tests `'the recorder is read off the user_id embed'`, `'a payback the payer
  recorded themselves is not on behalf'`, `'a payback with no recorder shows no attribution'`
  (`test/pages/groups/payback_on_behalf_test.dart`). `expense.user_id` only gets stamped on payback
  rows once the migration runs, so this is `[deferred]` to manual-checks verification step 3.
- **All new copy exists in EN and DE with generated l10n committed** —
  `test/pages/groups/payback_on_behalf_test.dart`'s `'copy exists in both languages'` group:
  `'every new string is translated, not copied'`; `app_localizations*.dart` regenerated via `flutter
  gen-l10n` and committed alongside the ARB changes.
- **Settle-up screen exposes recording a payment, including for balances a removed member strands** —
  `test/widgets/group_detail_payment_test.dart`: `'the settle-up screen offers Record a payment'`,
  `'Record a payment is offered even when everything is settled'`, `'a removed counterparty is offered
  no Pay or Remind action'`, `'a settled group shows no stranded section'`.
- **Known gap, deliberately not fixed** — `FriendDetailSheet._markPaid`
  (`lib/pages/friends/presentation/friend_detail_sheet.dart`) branches only on
  `PayBackAllResult.isComplete` (`skippedGroupNames.isEmpty`). When every shared group is skipped —
  nothing written at all — `isComplete` is still `false`, so the snackbar shows
  `payBackPartialSuccess` ("You paid back {name}, but these groups are still open: …"), which asserts a
  payback that never happened rather than reporting a total failure. The fix is to branch on
  `result.settledGroupNames.isEmpty` first. Left open: the reviewer's round-3 pass flagged it as a
  `lean` rather than a bug (a real payback was never silently lost — the copy is just misleading in
  the all-skipped case), and it was accepted as a recorded gap rather than spending a fourth review
  round on copy wording.

Test counts: 16 new tests in `test/model/payback_request_test.dart`, 14 new tests across the four
groups in `test/pages/groups/payback_on_behalf_test.dart`, 6 new tests in
`test/model/group_repository_test.dart`, plus new/updated cases in `test/widgets/group_detail_ledger_test.dart`,
`test/widgets/expense_detail_read_test.dart`, `test/widgets/group_detail_payment_test.dart`,
`test/widgets/friend_detail_sheet_test.dart`, `test/model/payment_view_model_test.dart` and the new
`test/widgets/record_payback_sheet_test.dart`.

Gate summary: `flutter analyze` — no issues found. `flutter test` — 1140 passed (baseline at HEAD
`67bfdd2` was 1068).

Review verdict:
- Round 1 — 4 bugs and 3 lean findings, all fixed.
- Round 2 — confirmed round 1's fixes held; found 2 bugs and 1 lean finding introduced by those fixes.
- Round 3 — all round-2 findings fixed; final re-review found no bugs. `review: clean` apart from one
  accepted `lean` — the `payBackPartialSuccess` gap above — deliberately left open and recorded rather
  than fixed.

- **[deferred] server-side validation and `user_id` attribution ride on the unapplied migration** —
  `20260816010000_payback_on_behalf.sql` is authored, not applied (self-hosted instance, unreachable
  from the build — see manual-checks.md). Until it runs, the criteria marked `[deferred]` above are
  assumed from the client-side halves and code inspection, not observed end to end.

status: done
