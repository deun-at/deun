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
  - Migration: extend `pay_back` with an explicit payer, defaulting to the caller; validate that payer and payee are distinct, both current members of the group.
  - Repository + call sites: optional `paidBy` on `GroupRepository.payBack`, existing callers untouched.
  - Recording attribution: persist and expose who recorded the payback; surface it in the ledger and expense read view.
  - Notification: both-parties notification naming the recorder, extending `sendGroupPayBackNotification`.
  - UI: choosing a payer when recording a payback, from the settle-up surface.
- Blockers: —

## Approach
- **Read this first:** `pay_back` and `update_group_member_shares` are not in `supabase/migrations/` — they exist only in the live self-hosted DB and predate the tracked migrations. Dump the current definition of `pay_back` from the live database before writing the migration; do not reconstruct it from the Dart call site, which only shows four parameters and tells you nothing about the body. Getting this wrong silently breaks every settle-up in the app.
- Keep the new parameter optional with a caller default so `payBackAll` and the settle-up sheet need no signature churn, and so a client that hasn't been updated keeps working against the new function.
- The client currently calls `pay_back` and then `update_group_member_shares` separately, with a one-shot retry to paper over partial state. Do not extend that pattern — if the new work needs more statements, prefer moving them inside the RPC where they are already transactional.
- Likely touchpoints: supabase/migrations/ (new migration), lib/pages/groups/data/group_repository.dart (`payBack`, `payBackAll`, notification), lib/pages/groups/presentation/group_detail_payment.dart (payer selection), lib/pages/groups/presentation/payment_view_model.dart (partitioning is per-current-user today), lib/pages/groups/presentation/group_ledger.dart (attribution), lib/l10n/app_en.arb + app_de.arb.
- Depends: —
- Parallel-with: group-member-removal

status: planned
