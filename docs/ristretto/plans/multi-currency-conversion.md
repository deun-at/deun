# multi-currency-conversion — Per-expense foreign currency with frozen conversion rate

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08)
- Flight: multi-currency
- Goal: An expense can be entered in a currency different from its group; it is converted into the group currency at a stored, user-overridable rate, and all balance math uses the converted amount.
- Acceptance:
  - The expense editor offers a currency picker (defaulting to the group currency); picking a foreign currency shows a rate field and the converted total in the group currency before saving.
  - The rate auto-fills from a free no-key rate API (frankfurter.app / ECB) for the expense date; the user can overwrite it manually; the used rate is stored on the expense and never silently changes afterwards ("frozen at save").
  - If the rate fetch fails (offline, API down), the user can still save by entering a rate manually; an error state explains why auto-fill is unavailable.
  - Group balances, shares, claim math, and the group total are computed from the converted (group-currency) amount; a foreign-currency expense of 100 USD at rate 0.90 contributes exactly 90.00 EUR (rounded via the existing 2-decimal boundary rounding).
  - The expense read view shows both the original amount + currency and the converted amount + rate used.
  - Editing a foreign-currency expense keeps its stored rate unless the user changes the rate, currency, or expense date (date change re-fetches and shows the new rate before save).
  - Rate must be > 0; validation rejects zero/negative/empty rates.
  - `flutter analyze` and `flutter test` pass, including new tests covering conversion rounding and rate validation.
## Approach
- Extend the schema: `conversion_rate` on `expense` (one rate per expense), original per-entry amount on `expense_entry` (nullable; null = amount already in group currency). Keep `expense_entry.amount` as the **converted group-currency value** — conversion happens once at save time in the app.
- This keeps every DB function untouched: `update_group_member_shares()` (rebuilds the `group_shares_summary` table), `get_user_spending_summary`, `get_group_monthly_statistics`, `pay_back`/`pay_back_all` all read `expense_entry.amount` directly (verified against live schema 2026-07-08). Only `save_expense_all` needs its explicit column lists extended to persist the new columns.
- Small rate service (plain HTTP via the already-installed supabase/http stack — check pubspec before adding anything) that fetches a date-scoped rate from frankfurter.app; no caching layer beyond the frozen stored rate.
- Likely touchpoints: `lib/pages/expenses/` (model, repository, editor `expense_detail.dart`, read view), `lib/pages/expenses/service/` (new rate service next to `receipt_parser.dart`), `lib/helper/helper.dart` (rounding), Supabase migration, both ARB files for new strings.
- Decisions / tradeoffs: conversion at save time (frozen rate) rather than live recomputation — balances stay stable and offline-safe; itemized/per-unit entries convert at the same single expense-level rate.
- Depends: multi-currency-foundation
- Parallel-with: —
- Blockers: —

status: planned
