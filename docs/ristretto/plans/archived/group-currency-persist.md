# group-currency-persist — `save_group_all` actually stores the group's currency

## Spec
- Source: bug found 2026-08-16 while reading the live schema dump to answer an unrelated question
  about `save_group_all`; confirmed against production data the same day.
- Flight: multi-currency
- Goal: The currency a user picks on the group create and edit forms is persisted, instead of being
  silently discarded server-side and falling back to the column default.

## The bug
`group.currency_code` shipped with `20260712000000_add_group_currency_code.sql`
(`multi-currency-foundation`), the picker shipped with it on both the create and edit forms
(`_CurrencyField`, `group_detail_edit.dart:463` — it takes an optional group and initialises from
`group?.currencyCode`, so it is live on both paths), and `GroupRepository.saveAll`
(`group_repository.dart:219`) has always packed `currency_code` into the `_group` jsonb.

`save_group_all` never listed the column in its UPDATE SET or its INSERT column list. The value was
dropped on every write. With `currency_code text default 'EUR' not null`, every group in the instance
is EUR whatever the user picked.

Confirmed against production 2026-08-16: `select currency_code, count(*) from public."group" group by
1;` returns exactly one row — `EUR, 110`.

There is one path that would have written it correctly — `_saveAllLegacy` does a plain
`.upsert(upsertVals)` — but it only runs when the RPC is missing, and it isn't.

## Contract
- Acceptance:
  - `[deferred]` Creating a group with a non-EUR currency persists that currency.
  - `[deferred]` Changing an existing group's currency persists it, and relabels existing amounts
    without converting any value — matching what the edit form's own note already promises.
  - `[deferred]` A group save that does not touch the picker leaves `currency_code` unchanged rather
    than resetting it to the default.
  - `[deferred]` No pre-existing group's currency changes as a result of applying this. There is no
    backfill.
  - Every other behaviour of `save_group_all` is unchanged, in particular the `group-member-removal`
    member handling: no `delete from group_member`, `removed_at` cleared on re-add, `is_favorite`
    preserved.
- Provides: —
- Consumes: —
- Decisions:
  - No backfill -> the 110 existing EUR groups are legitimately EUR. Nobody was ever able to set them
    to anything else, so there is no "intended" value to restore. Guessing one from member locale or
    expense history would invent data.
  - Fix `save_group_all` rather than routing currency through a separate client-side write -> the
    column belongs to the group row and the RPC is the single transactional write path for it; adding
    a second writer is how the two-answers-for-one-value class of bug starts.
  - Shipped as a standalone migration, not folded into a multi-currency feature -> it is a straight
    bugfix against work already marked `done`, and the correction should be legible as such rather
    than buried in a feature diff.
  - `coalesce(r.currency_code, 'EUR')` on the INSERT -> the column is `not null`, and an older client
    that omits the key from `_group` entirely must not start failing group creation.
- Units:
  - Migration replacing `save_group_all` with `currency_code` added to both statements, everything
    else reproduced verbatim from the live definition.
- Blockers: —
- Deferred DB work: **all of it.** This feature is a migration and nothing else — there is no Dart
  change, because the client already sends the value correctly, and therefore no unit test can
  observe the fix without a live connection. Every acceptance criterion above is `[deferred]` to the
  manual-checks verification steps. This is the rare case where `code-complete` carries no code.

## Approach
`jsonb_populate_record(null::public."group", _group)` already materializes `r.currency_code`; it was
simply never selected. Two lines.

The rest of the function body is copied verbatim from the schema dump taken 2026-08-16 (i.e. after
`20260815010000_group_member_removal.sql` was applied), so the diff against the live definition is
the currency change and nothing else. Re-dump and diff before applying if anything else has been
changed by hand in the meantime.

- Likely touchpoints: `supabase/migrations/20260816000000_group_currency_code_persist.sql` (only)
- Depends: —
- Parallel-with: multi-currency-core

## Consequences for the roadmap
Two rows marked `done` did not work end to end and are corrected by this, not re-opened:
- **multi-currency-foundation** — its picker wrote to a field that never persisted.
- **group-create-simplify** — one of the three fields it narrowed the create form to was discarded.

`multi-currency-group` and `multi-currency-expense-rate` both build on `Group.currency` being a real
per-group value. Neither should be pulled until this is applied.

## Evidence
- **Migration applied 2026-08-16** — `20260816000000_group_currency_code_persist.sql` executed against
  the live self-hosted instance by Jakob.
- **The bug was confirmed empirically before the fix**, not inferred: the live schema dump showed
  `currency_code` absent from both statements of `save_group_all`, and
  `select currency_code, count(*) from public."group" group by 1;` returned a single row, `EUR, 110`.
- **No gates were run** — this feature changed no Dart, so `flutter analyze` / `flutter test` have
  nothing to say about it. Every acceptance criterion is `[deferred]` and none has been reported as
  walked, so they are all *assumed*, not *observed*. The cheapest confirmation is recorded in
  [manual-checks.md](../../manual-checks.md).
- `review: skipped (migration only, no code)`.

status: done
