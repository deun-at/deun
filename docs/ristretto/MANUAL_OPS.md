# Manual operations queue

Deun's Supabase instance is **self-hosted** and is not reachable from the build. Migrations in
`supabase/migrations/` are therefore *authored* by feature work but **never applied** by it — they
are applied by hand, by Jakob, against the live instance.

This file is the queue. A feature that needs a schema or RPC change appends an entry here as part of
its own work, and does not treat the change as done until the entry is ticked off.

## The rule features follow

A feature that needs a database change **must still run through green**. It does that by:

1. Writing the migration into `supabase/migrations/` with a timestamped filename. Never editing an
   already-applied migration — always a new one.
2. Writing its Dart against the post-migration shape, with tests that use fakes, fixtures or models
   rather than a live connection. The gates (`dart format`, `flutter analyze`, `flutter test`) do not
   touch a database, so this passes.
3. Marking every acceptance criterion that cannot be observed without the applied migration as
   **`[deferred]`** in its plan, so the difference between "tested" and "assumed" stays visible.
4. Appending an entry below saying exactly what to run and how to confirm it worked.

A feature is **code-complete** when the gates pass. It is **done** when its entry here is ticked.
Do not mark a roadmap row done on the strength of green gates alone when it has an open entry here.

## Pending

| Feature | What to apply | How to verify | Status |
|---------|---------------|---------------|--------|
| group-member-removal | `supabase/migrations/20260815010000_group_member_removal.sql` — adds `group_member.removed_at`, fixes `update_group_member_shares`' `total_share_amount` counterparty semi-join, and stops `save_group_all` deleting members. Then recompute every group once: `select public.update_group_member_shares(g.id, null::uuid) from public."group" g;` | 1) `select removed_at from public.group_member limit 1;` succeeds. 2) In a group with expenses, note `groupSharesSummary` for every member, remove a settled member with history, and confirm the map is identical and the group list total is unchanged. 3) Remove a settled member with no expenses at all and confirm their `group_member` row is gone. 4) Re-add a removed member and confirm `removed_at` is null and their `expense_entry_share` rows are unchanged and not duplicated. 5) Open the group on a second client and confirm the roster updates without a manual refresh. 6) Edit a group without touching its members (e.g. rename it) and save, then confirm no `group_member` row disappeared and every member's `is_favorite` survived — this is the one non-deferred write-path criterion (`saveAll`/`save_group_all` no longer delete members merely absent from the submitted list) and it is only exercised end-to-end here, not by a unit test. | pending |
| settle-residue | `supabase/migrations/20260815020000_settle_residue_exact_payback.sql` — adds `pay_back_exact`, which snaps the settled amount to the exact (unrounded) outstanding value and delegates the insert to `pay_back`. `pay_back` is unchanged. | 1) `select public.pay_back_exact(g.id, 'a@x', 'b@x', 0);` on a throwaway group succeeds (function exists), then delete the row it created. 2) In a group with one 10.00 expense split three ways, settle up as each debtor and confirm every member's `total_share_amount` is exactly `0`: `select paid_for, total_share_amount from group_shares_summary where group_id = '<id>';` — before this migration the payer is left at ~0.0067 and the group hero shows 0.01. 3) Confirm the group leaves the active tab and appears under done. 4) Enter a deliberate partial payment (e.g. 5.00 against a 12.00 debt) and confirm the inserted `expense_entry.amount` is exactly 5.00 — the snap must not touch a partial. 5) Repeat 2) in a simplified-expenses group, where the amount comes from the client's greedy assignment, and confirm the settling member's net is exactly `0`. 6) Confirm `payBackAll` from the friend sheet settles the pair's balance in every shared group to exactly `0` in one action — in a group with 3+ members the user's own net may still carry other members, so check the pair's balance, not the net. | pending |

## Applied

| Feature | What was applied | Date |
|---------|------------------|------|
| — | `20260815000000_baseline_ledger_functions.sql` — baseline only, reproduces the functions already live, safe to skip | not required |

## Known deferred work by feature

Recorded at prep time so the size of the manual tail is visible before anything is pulled.

- **settle-residue** — client half (unify the three settled thresholds, make the two client roundings
  consistent) needs no database work and is fully testable. The server half — making the settled
  amount the exact outstanding value rather than a client-rounded one — is
  `supabase/migrations/20260815020000_settle_residue_exact_payback.sql`, which adds `pay_back_exact`
  (delegating the insert to the untouched `pay_back`), and is deferred.
- **group-member-removal** — needs `group_member.removed_at timestamptz null`, and a fix to
  `update_group_member_shares` so its `total_share_amount` subquery joins `group_member` (today it
  does not, which is the ghost-share bug). Both deferred. All client logic and the pure
  `resolveMemberRemoval` decision function are testable without them.
- **payback-on-behalf** — the core capability needs **no** migration: `pay_back` already accepts
  `_paid_by` as a parameter and the restriction is one hardcoded line in the client. Only the
  validation (payer ≠ payee, both current members) is deferred.
- **multi-currency-expense-rate** — needs new columns on the expense/entry rows for the original
  currency, the frozen rate and the converted amount. Deferred.
- **multi-currency-rate-source** — needs a Supabase Edge Function deployed to the self-hosted
  instance. Deferred; note that edge functions on this instance update via force-recreate.
- **multi-currency-core**, **multi-currency-group**, **group-form-field-structure**,
  **group-create-simplify**, **expense-delete-settled-guard**, **expense-notification-route**,
  **expense-editor-edit-labels** — no database work at all. The active/done group filter that
  `multi-currency-group` touches is built client-side in `GroupRepository.fetchData`, not in a view,
  so changing its threshold is a Dart change.
