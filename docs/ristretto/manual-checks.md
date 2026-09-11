# Manual checks

Deun's Supabase instance is **self-hosted** and is not reachable from the build. Migrations in
`supabase/migrations/` are therefore *authored* by feature work but **never applied** by it — they
are applied by hand, by Jakob, against the live instance.

This file is the queue. A feature that needs a schema or RPC change appends an entry here as part of
its own work, and does not treat the change as done until the entry is ticked off.

A check line reads `- [ ] **proves** · <criterion> · <what was out of reach> · <what to do>`. The
third slot is the reason the build could not reach it — on this project almost always the
self-hosted instance.

## The rule features follow

A feature that needs a database change **must still run through green**. It does that by:

1. Writing the migration into `supabase/migrations/` with a timestamped filename. Never editing an
   already-applied migration — always a new one.
2. Writing its Dart against the post-migration shape, with tests that use fakes, fixtures or models
   rather than a live connection. The gates (`dart format`, `flutter analyze`, `flutter test`) do not
   touch a database, so this passes.
3. Marking every acceptance criterion that cannot be observed without the applied migration as
   **`[human]`** in its plan, so the difference between "tested" and "assumed" stays visible.
4. Appending an entry below saying exactly what to run and how to confirm it worked.

A feature is **done** when its gates pass. An open entry here does **not** hold its roadmap row open,
and `code-complete` is no longer a status — it stalled every dependent feature behind hand-applied
work and cost a full brew run on 2026-08-15. Mark the row `done`, add a `⚠ migration pending` marker
to it, and leave the entry here open until the migration is actually applied.

This file, not the roadmap, is the authority on what has been applied and verified. A `done` row can
carry `[human]` criteria that nobody has ever observed. Check here before shipping.

## Open

- [ ] **proves** · multi-currency-expense-rate: saving stores the converted amount as the ledger
  value; provenance survives a save/reload round trip; the stored rate and converted amount are
  frozen across non-amount edits · self-hosted instance, not reachable from the build · apply
  `20260816020000_expense_entry_currency_rate.sql` — three nullable provenance columns on `expense`,
  one on `expense_entry`, one on `expense_entry_share`, and `save_expense_all` re-stated to thread
  all five. No backfill. Then verify:
  1. `select original_currency_code, conversion_rate, rate_date from public.expense limit 1;` returns
     columns (all null).
  2. `select original_amount from public.expense_entry limit 1;` and
     `select original_fixed_amount from public.expense_entry_share limit 1;` each return a column.
  3. In a EUR group, add an expense of 3000 entered in JPY at rate 0.0058; confirm
     `select amount from public.expense_entry where expense_id = '<id>';` is `17.40` and
     `select original_amount ...` is `3000`.
  4. Confirm `select conversion_rate, rate_date, original_currency_code from public.expense where id = '<id>';`
     is `0.0058`, today, `JPY`.
  5. Edit that expense's name only, save, and confirm all four values are byte-identical.
  6. Confirm `group_shares_summary` for the group totals `17.40`, not `3000`.
  7. In a EUR group, add a 4.50 CHF expense at rate 0.9432 split **exact** 1.50/1.50/1.50; confirm
     `select fixed_amount, original_fixed_amount from public.expense_entry_share where expense_entry_id = '<entry id>';`
     is `1.41` / `1.50` per row, then edit only its name, save, and confirm all three `fixed_amount`
     values and the entry `amount` (4.23) are byte-identical.

- [ ] **proves** · group-member-removal: editing a group without touching its members leaves the
  roster and favourites intact (the one non-deferred write-path criterion, which has no unit
  coverage) · self-hosted instance, not reachable from the build · edit a group without touching its
  members (e.g. rename it), save, then confirm no `group_member` row disappeared and every
  `is_favorite` survived. Also confirm a settled member with history soft-removes with an identical
  `groupSharesSummary`, and one with no history is deleted outright.

- [ ] **proves** · settle-residue: settling leaves no rounding remainder, and a partial payment
  inserts exactly the amount paid · self-hosted instance, not reachable from the build · settle a
  10.00 expense split three ways and confirm every member's `total_share_amount` is exactly `0`, in
  both default and simplified groups; then confirm a partial payment (5.00 against a 12.00 debt)
  still inserts exactly 5.00.

- [ ] **proves** · group-currency-persist: a group's chosen currency is stored, and existing groups
  are untouched (every criterion in that plan needs the database — the feature is a migration with no
  Dart) · self-hosted instance, not reachable from the build · create a group picking USD and check
  `select currency_code from public."group" where id = '<id>';` returns `USD`; then confirm
  `select currency_code, count(*) from public."group" group by 1;` still shows the 110 pre-existing
  groups as EUR.

- [ ] **proves** · multi-currency-rate-source: rates are fetched through a Supabase Edge Function
  rather than directly from the client · Edge Function must be deployed to the self-hosted instance,
  which updates by force-recreate rather than in place · ? — the feature is still `planned`; fill
  this in when it is built.

- [ ] **proves** · group-member-add-flow: a member added by one client appears on another client's
  open group detail through the existing realtime path · needs two live clients against the
  self-hosted instance · ? — the feature is still `planned`; fill this in when it is built.

## Applied

| Feature | What was applied | Date |
|---------|------------------|------|
| — | `20260815000000_baseline_ledger_functions.sql` — baseline only, reproduces the functions already live, safe to skip | not required |
| group-member-removal | `20260815010000_group_member_removal.sql` — `group_member.removed_at`, the `update_group_member_shares` counterparty semi-join fix, and `save_group_all` no longer deleting absent members. Applied by Jakob against the live instance. | 2026-08-16 |
| settle-residue | `20260815020000_settle_residue_exact_payback.sql` — adds `pay_back_exact`; `pay_back` unchanged. Applied by Jakob against the live instance. | 2026-08-16 |
| group-currency-persist | `20260816000000_group_currency_code_persist.sql` — `currency_code` added to `save_group_all`'s UPDATE SET and INSERT column list; no backfill. Applied by Jakob against the live instance. | 2026-08-16 |
| payback-on-behalf | `20260816010000_payback_on_behalf.sql` — `pay_back` gains payer≠payee + both-current-member validation and records `auth.uid()` into `expense.user_id`. Applied by Jakob against the live instance. | 2026-08-16 |

The migrations above are **applied**, which is what unblocked the dependent features. Their numbered
verification steps have **not** been reported as run — that is what the corresponding open `proves`
lines above are for.

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
- **multi-currency-expense-rate** — `supabase/migrations/20260816020000_expense_entry_currency_rate.sql`
  adds `expense.original_currency_code`, `expense.conversion_rate`, `expense.rate_date`,
  `expense_entry.original_amount` and `expense_entry_share.original_fixed_amount`, and re-states
  `save_expense_all` to thread them. The rule behind the two amount columns: every money column the
  editor reloads into a field needs an entry-currency twin, because the field holds entry-currency
  amounts and the column holds the converted ledger value. Deferred. All
  conversion arithmetic, freezing, switch-back and the no-implicit-rate guard are pure functions and
  are fully covered without a database. Read paths tolerate the pre-migration schema: the expense
  select is `*`, so the absent columns simply read null, and the currency-lock probe swallows the
  undefined-column error and reports "unlocked".
- **multi-currency-rate-source** — needs a Supabase Edge Function deployed to the self-hosted
  instance. Deferred; note that edge functions on this instance update via force-recreate.
- **multi-currency-core**, **multi-currency-group**, **group-form-field-structure**,
  **group-create-simplify**, **expense-delete-settled-guard**, **expense-notification-route**,
  **expense-editor-edit-labels** — no database work at all. The active/done group filter that
  `multi-currency-group` touches is built client-side in `GroupRepository.fetchData`, not in a view,
  so changing its threshold is a Dart change.

## Retired — not tracked by ristretto

Rollout steps from an older format. ristretto no longer reads this section;
keep or delete it as you like.

- [ ] **deploy** · — · live build · until the branch ships, the live app still removes members by
  omission through `save_group_all`, which the `group-member-removal` migration made a no-op. Member
  removal from the group edit form will silently do nothing on the currently deployed build.
