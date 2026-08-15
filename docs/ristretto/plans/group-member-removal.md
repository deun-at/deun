# group-member-removal — Removing a group member: defined semantics instead of a silent wipe

## Spec
- Source: idea (NOTES.md bug 2, Jakob 2026-07-24, branch `claude/group-management-issues-ifybxc`)
- Flight: —
- Goal: Make removing a member from a group a deliberate, defined operation that can never strand a debt or silently alter historical balances.

## Contract
- Acceptance:
  - Attempting to remove a member whose group balance magnitude is `>= 0.005` performs **no write** to `group_member` and surfaces a message naming the outstanding amount in the group's currency.
  - **[deferred]** Removing a member whose balance is settled (`< 0.005`) but who appears in at least one expense keeps **every** existing `expense_entry_share` row for them byte-identical, marks them removed, and leaves the group's per-member balance map identical before and after (asserted by comparing the full `groupSharesSummary` map). *This is the criterion that proves the ghost shares are gone — it is the single most important thing to check once the migration is applied.*
  - **[deferred]** Removing a member with zero expense involvement deletes their `group_member` row outright — no tombstone left behind.
  - A removed-with-history member does **not** appear in the new-expense "paid by" picker or the share/split pickers, but **does** still appear on their past expenses in the group ledger and in the group detail balance list.
  - Saving the group edit form no longer deletes `group_member` rows for members merely absent from the submitted `group_members` list; membership shrinks **only** through the explicit removal path.
  - **[deferred]** Re-adding a removed-with-history member clears their removed marker and restores them to all pickers, with their historical shares unchanged and not duplicated.
  - The removal-outcome decision is a pure function, unit-tested at the epsilon boundary: `0.004` settles, `0.005` blocks, and both signs of the balance block symmetrically.
  - **[deferred]** A member removal performed by one client is reflected on other clients' open group detail via the existing realtime path, with no stale roster.
- Provides:
  - `GroupMember.removedAt: DateTime?` and `GroupMember.isRemoved: bool`
  - `MemberRemovalOutcome` — one of `blocked(outstanding: double)` · `softRemoved` · `hardRemoved`
  - `resolveMemberRemoval({balance: double, hasExpenseHistory: bool}): MemberRemovalOutcome` (pure)
  - `GroupRepository.removeMember(groupId: String, email: String): Future<MemberRemovalOutcome>`
- Consumes: —
- Decisions:
  - What happens on removal -> Block while unsettled; soft-remove once settled if they have history; hard-remove if they have none. (Jakob, prep 2026-08-15)
  - Settled threshold -> route through the single settled predicate that [settle-residue](settle-residue.md) unifies; do **not** invent a new constant and do **not** reach for `_kSettledEpsilon` directly. If this feature is pulled before `settle-residue`, use `_kSettledEpsilon = 0.005` from `payment_view_model.dart` and expect that call site to be swept up later. (Revised 2026-08-15: the original plan said this feature would not unify the thresholds; `settle-residue` now owns that.)
  - Soft-remove representation -> a nullable `removed_at` timestamp on `group_member`, not a boolean, so the event is auditable and re-adding is just clearing it.
  - Share recalculation -> `update_group_member_shares` must keep computing rows for removed-with-history members; removal changes visibility, never ledger math.
  - Redistribution of a removed member's shares was explicitly rejected — it would rewrite historical expense amounts so past receipts stop matching the app.
- Units:
  - Schema + model: migration adding `group_member.removed_at timestamptz null`; `GroupMember` parses/serialises it; `Group.groupSelectString` carries it through.
  - Pure decision logic: `resolveMemberRemoval` + `MemberRemovalOutcome`, fully unit-tested at the epsilon boundary, no Supabase involvement.
  - Repository: `GroupRepository.removeMember` applying the outcome, and removing the implicit delete-all/re-insert of `group_member` from the `saveAll` legacy path (and the matching behaviour in the `save_group_all` RPC).
  - Read-path filtering: removed members excluded from expense paid-by/share pickers and from member search's "add" candidates, retained in ledger, group detail balances and past expenses.
  - UI: removal affordance in the group edit member list showing the block reason (with the outstanding amount) or the soft-remove confirmation; EN + DE strings.
- Blockers: —
- Deferred DB work: this feature runs through green without a database. Author the migration, write
  the Dart against its post-migration shape, test with fakes, and append an entry to
  [MANUAL_OPS.md](../MANUAL_OPS.md) rather than waiting. Two changes are deferred:
  (1) `group_member.removed_at timestamptz null`; (2) `update_group_member_shares` — its
  `total_share_amount` subquery must join `group_member` so shares belonging to a removed member stop
  counting toward everyone else's balance. Criteria marked `[deferred]` above cannot be observed until
  both are applied; every other criterion must genuinely pass.

## Confirmed mechanism (2026-08-15)
`update_group_member_shares` was recovered from the live instance and is now in
`supabase/migrations/20260815000000_baseline_ledger_functions.sql`. It explains the corruption
exactly, and the explanation is worse than "the roster is stale":

- The **outer** query builds `group_shares_summary` from `group_member gm`, joining shares with
  `ees.email = gm.email`. Delete a member's row and their pairwise entries vanish cleanly.
- The **`total_share_amount` subquery never joins `group_member` at all.** It walks
  `expense → expense_entry → expense_entry_share` filtered only by `group_id`, so a removed member's
  surviving `expense_entry_share` rows keep counting toward every *remaining* member's net balance.

The result: the removed person disappears from the per-counterparty rows that the group **detail**
renders, while the group **list** — which reads `total_share_amount` — still carries their share.
The two screens disagree permanently, and the phantom amount belongs to nobody, so no settle-up can
ever clear it. That is the reported "balances get confused" and "breaks the group list for everyone",
and it is a data-integrity bug affecting every member, not a display glitch.

This raises the stakes on the acceptance criterion that balances be **identical** before and after a
soft-remove: it is the criterion that proves the ghost shares are gone.

## Approach
- Two independent defects have to be fixed together. The client-side one: removal has no code path of
  its own, so dropping a chip from the form makes `saveAll` delete the membership row while the
  `expense_entry_share` rows survive. The server-side one: even a *correct* removal would corrupt
  balances, because the subquery above counts shares with no living member behind them. Fixing only
  the entry point leaves the corruption reachable through any other path that deletes a member row.
- Soft-remove is what makes the server side tractable: if the `group_member` row survives with a
  `removed_at` stamp, the subquery keeps finding a member behind every share and the arithmetic stays
  whole. Filtering removed members out of the summary is then a display concern, not a ledger one.
- Existing groups may already carry ghost shares from removals performed before this fix. Decide at
  pull time whether to detect and repair them — a one-off audit query — or to leave them; do not
  assume the fix is retroactive, because it is not.
- Prefer enforcing the block server-side as well as in the UI, since the same guard protects
  concurrent clients; the client-side check is for the message, not for correctness.
- Likely touchpoints: lib/pages/groups/data/group_repository.dart (saveAll legacy path, new removal path), lib/pages/groups/data/group_member_model.dart, lib/pages/groups/data/group_model.dart (select string, shares summary), lib/pages/groups/presentation/group_member_search.dart (candidate list), lib/pages/groups/presentation/group_detail_edit.dart (removal affordance), lib/pages/expenses/presentation/expense_detail.dart (pickers), supabase/migrations/ (new migration).
- Depends: —
- Parallel-with: group-member-add-flow

status: planned
