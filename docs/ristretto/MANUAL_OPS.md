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
| — | *(queue empty)* | — | — |

## Applied

| Feature | What was applied | Date |
|---------|------------------|------|
| — | `20260815000000_baseline_ledger_functions.sql` — baseline only, reproduces the functions already live, safe to skip | not required |
| group-member-removal | `20260815010000_group_member_removal.sql` — `group_member.removed_at`, the `update_group_member_shares` counterparty semi-join fix, and `save_group_all` no longer deleting absent members. Applied by Jakob against the live instance. | 2026-08-16 |
| settle-residue | `20260815020000_settle_residue_exact_payback.sql` — adds `pay_back_exact`; `pay_back` unchanged. Applied by Jakob against the live instance. | 2026-08-16 |
| group-currency-persist | `20260816000000_group_currency_code_persist.sql` — `currency_code` added to `save_group_all`'s UPDATE SET and INSERT column list; no backfill. Applied by Jakob against the live instance. | 2026-08-16 |

### Verification still outstanding

Both migrations are **applied**, which is what unblocks the dependent features. The numbered
verification steps that were recorded with them have **not been reported as run**, so the criteria
marked `[deferred]` in the two archived plans remain *assumed*, not *observed*. Worth walking once
against a real group before the branch ships:

- **group-member-removal** — step 6 is the one **non-deferred** write-path criterion and has no unit
  coverage: edit a group without touching its members (e.g. rename it), save, then confirm no
  `group_member` row disappeared and every `is_favorite` survived. Also confirm a settled member with
  history soft-removes with an identical `groupSharesSummary`, and one with no history is deleted
  outright.
- **settle-residue** — settle a 10.00 expense split three ways and confirm every member's
  `total_share_amount` is exactly `0`, in both default and simplified groups; then confirm a partial
  payment (5.00 against a 12.00 debt) still inserts exactly 5.00.
- **group-currency-persist** — every criterion in that plan is `[deferred]`, because the feature is a
  migration with no Dart and nothing a unit test can observe. The cheapest confirmation is to create
  a group picking USD and check `select currency_code from public."group" where id = '<id>';` returns
  `USD`; then confirm `select currency_code, count(*) from public."group" group by 1;` still shows the
  110 pre-existing groups as EUR.

**Deploy note:** until the branch ships, the live app still removes members by omission through
`save_group_all`, which this migration made a no-op. Member removal from the group edit form will
silently do nothing on the currently deployed build.

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
