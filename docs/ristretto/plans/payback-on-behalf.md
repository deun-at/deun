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
  - A payback where payer and payee are the same member is rejected before any write.
  - A payback naming a member who is not in the group, or who is soft-removed, is rejected before any write.
  - Recording a payback on someone's behalf notifies the **payee** and the **payer** (when the payer is a real user, not a guest) — the person whose money moved must find out, and the notification must name who recorded it.
  - The existing self-payback path (`_paid_by = current user`) produces byte-identical writes to today — this feature extends the RPC, it does not re-route the common case.
  - The ledger and expense read view show who recorded a payback when that differs from the payer.
  - All new copy exists in EN and DE with generated l10n committed.
- Provides:
  - `GroupRepository.payBack(context, groupId: String, email: String, amount: double, {paidBy: String?, sendNotification: bool}): Future<void>` — `paidBy` defaulting to the current user preserves every existing call site
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
  author it, mark those criteria `[deferred]`, append to [MANUAL_OPS.md](../MANUAL_OPS.md), continue.

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

status: planned
