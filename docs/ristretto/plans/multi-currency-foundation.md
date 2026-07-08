# multi-currency-foundation — Currency on groups & expenses + currency-aware formatting

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08)
- Flight: multi-currency
- Goal: Every group has a currency (default EUR); all money in the app is formatted with that currency instead of the hardcoded €.
- Acceptance:
  - `group` and `expense` tables have a `currency_code` column (ISO 4217, e.g. "EUR", "USD"); existing rows backfill to "EUR"; expense rows default to their group's currency.
  - Group create/edit lets the user pick the group currency from a curated list (at minimum EUR, USD, GBP, CHF, and the other major ISO codes `intl` can format); new groups default to EUR.
  - Changing a group's currency relabels existing amounts (no value conversion) and the edit UI states this.
  - No user-visible amount anywhere in the app renders a hardcoded €: group list, group detail, expense read/edit, claim page, friends, statistics, snackbars, and push-notification strings all format via the group's (or expense's) currency code with correct locale-aware symbol placement (e.g. "$1,234.56" vs "1.234,56 €").
  - A group in USD and a group in EUR display side by side in the group list with their own symbols.
  - `flutter analyze` and `flutter test` pass; existing money-math tests unaffected (formatting only, no arithmetic changes).
## Approach
- Add `currency_code` via a Supabase migration; thread it through `Group`/`Expense` models and repositories.
- Schema facts (from live DB, 2026-07-08): amounts live on `expense_entry.amount` (numeric), not on `expense`. `expense.currency_code` should be nullable meaning "group currency" — then the `pay_back`/`pay_back_all` RPCs (which insert expense rows with explicit column lists) need no change. `save_expense_all` also uses explicit column lists and must be extended to pass the new expense column.
- Replace the ~15 generated l10n `NumberFormat.currency(name: '€')` call sites: change the ARB placeholder strategy so amount strings take a currency code (or pre-formatted string) instead of baking € into `toCurrency`/`expenseDisplayAmount`/etc.; `MoneyText` gains a currency parameter.
- Currency list + symbol formatting comes from the already-installed `intl` package — no new dependency.
- Likely touchpoints: `lib/l10n/*.arb` + regenerated l10n, `lib/widgets/restyle/money_text.dart`, `lib/pages/groups/` (model, repository, create/edit UI, list, detail), `lib/pages/expenses/` (model, read/edit), `lib/pages/friends/`, `lib/pages/statistics/`, new Supabase migration.
- Decisions / tradeoffs: relabel-not-convert on group currency change (conversion arrives with multi-currency-conversion); per-expense currency column is added now but stays equal to the group currency until the next feature, so the schema doesn't need a second migration.
- Note: `group_shares_summary` is a **table**, rebuilt per group by the `update_group_member_shares()` function on every save — it stores derived sums only, no currency needed there. The base schema is not in `supabase/migrations`; only the new migration goes in the repo (self-hosted instance at api.deun.app, applied via dashboard/psql, not `supabase db push` to cloud).
- Depends: —
- Parallel-with: —
- Blockers: —

status: planned
