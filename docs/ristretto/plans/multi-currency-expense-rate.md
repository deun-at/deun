# multi-currency-expense-rate — Per-expense entry currency with a manual, frozen rate

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08; replanned 2026-08-11)
- Flight: multi-currency
- Goal: An expense can be entered in a currency other than its group's. The user supplies the rate,
  the app converts once at entry, and both the converted amount and the rate are frozen on the row.
  The ledger stays single-currency, so balances and settlement are unchanged.

## Contract
- Acceptance:
  - [auto] The expense editor offers a currency for the amount, defaulting to the group's currency. Choosing
    a different one reveals a rate field and a live preview of the resulting group-currency amount.
  - [human] Saving stores the converted group-currency amount as the ledger value. Balances, settlement
    suggestions, group totals and statistics read only that value and never the original.
  - [human] The original amount, original currency, rate and rate date survive a save/reload round trip and
    are shown on the expense read view (the amount as entered, the rate applied, and the date that
    rate is attributed to).
  - [human] The stored rate and converted amount are frozen: editing an expense's name, category, payer,
    participants, split or date leaves both untouched. Nothing in this feature ever recomputes a
    saved expense.
  - [auto] There is no implicit rate. An expense in a currency other than the group's cannot be saved
    without an explicitly supplied rate — no 1:1 fallback, no silent substitution.
  - [auto] Balance arithmetic is unchanged: every existing money-math test passes without its expected
    values being edited, and a group containing only group-currency expenses produces identical
    balances to before this feature.
  - [auto] Conversion respects both currencies' decimal digits: 3,000 JPY into a EUR group at 0.0058 stores
    17.40 EUR; 20 EUR into a JPY group at 172 stores 3,440 JPY with no fractional part.
  - [auto] The last rate the user entered manually for a given group and source currency prefills the next
    expense entered in that currency in that group, until they change or reset it — so a group can
    hold one agreed rate for a whole trip without a separate concept for it.
  - [auto] A group's currency picker is disabled once any expense in it carries a different original
    currency (the guardrail promised by [multi-currency-group](multi-currency-group.md) becomes
    reachable here).
  - [auto] `flutter analyze` and `flutter test` pass, including tests for the conversion arithmetic across a
    0-decimal and a 2-decimal currency in both directions, and a test that editing a non-amount field
    leaves the stored rate and converted amount byte-identical.
- Provides:
  - `Expense.originalCurrencyCode -> String?`, `.conversionRate -> double?`, `.rateDate -> String?`
  - `ExpenseEntry.originalAmount -> double?`
  - `convertToGroupCurrency(double amount, double rate, Currency target) -> double`
  - `stickyRate(String groupId, Currency from) -> double?`
  - `setStickyRate(String groupId, Currency from, double rate) -> Future<void>`
- Consumes: `Currency`, `kSupportedCurrencies`, `roundCurrency`, `formatMoney` (from
  [multi-currency-core](multi-currency-core.md)); `Group.currency`, `showCurrencyPicker`,
  `canChangeGroupCurrency` (from [multi-currency-group](multi-currency-group.md))
- Decisions:
  - Convert at entry, client-side, before the write -> the stored ledger value stays one number in one
    currency, so `save_expense_all`, `pay_back`, `update_group_member_shares` and
    `group_shares_summary` keep their existing logic. These are the functions that live only on the
    self-hosted instance and are applied by hand; not changing their arithmetic is the single largest
    risk reduction available in this flight.
  - The original amount, currency, rate and rate date are provenance only and are never read by
    balance math -> this is what makes conversion repeatable and non-destructive, and it is the
    difference between this design and the one that produces "it screwed up hundreds of my past
    transactions".
  - **Switching an expense back to the group currency re-converts the entered amounts at the frozen
    rate** (Jakob, 2026-08-16) -> the fields hold amounts in the *entry* currency, so leaving them as
    typed would save a 3000 JPY expense as 3000 EUR, and clearing them would silently discard the
    user's numbers. Re-converting at the rate the expense was already carrying preserves the value the
    ledger has today: switching a converted 17.40 EUR expense back to EUR leaves 17.40 EUR, not 3000.
    The provenance clears in the same step, as it already did. This closes the gap that blocked the
    feature on the 2026-08-16 brew run — the contract had decided only the provenance half.
  - Rate and rate date live on `expense`; original amount lives on `expense_entry` -> the currency and
    rate are facts about the expense as entered, while amounts are per-entry, matching where
    `amount` already lives.
  - The rate is user-supplied in this feature, with no automatic source -> a fetched mid-market rate
    never matches what the member's bank actually charged, which is the most-cited complaint in the
    category; the override is the feature, and prefill
    ([multi-currency-rate-source](multi-currency-rate-source.md)) is the convenience on top.
  - The sticky rate is a local prefill, persisted with `async_preferences` alongside theme and
    notification preferences, not synced -> it only seeds the next form; correctness lives in the
    frozen per-row value, and two members legitimately get different rates for the same day
    (exchange office vs card).
  - Refuse to save rather than defaulting to 1:1 -> a silent 1:1 fallback is a confirmed, repeated
    failure in shipped competitors and destroys trust in every number in the group.
- Units:
  - Migration adding rate and original-currency columns to `expense` and an original-amount column to
    `expense_entry`, plus threading them through `save_expense_all`.
  - Model and repository round-trip for the provenance fields.
  - Expense editor: currency selector, rate field, live converted preview, and the no-implicit-rate
    guard.
  - Expense read view: show the amount as entered, the rate, and the rate's date.
  - Sticky per-group rate prefill and reset.
  - Wire `canChangeGroupCurrency` to real expense currencies so the group picker locks correctly.
- Manual-Checks: [manual-checks.md](../manual-checks.md) — apply and verify `20260816020000_expense_entry_currency_rate.sql`
- Blockers: —
- Deferred DB work: needs new columns for the entry's original currency, the frozen rate and the
  converted amount. Author the migration, write the model and editor against its post-migration
  shape, test the conversion and freezing logic as pure functions with fixtures, mark the
  persistence criteria `[deferred]`, and append to [manual-checks.md](../manual-checks.md). The rate maths
  is the risky part and it is fully testable without a database — put the effort there.

## Approach
The whole design rests on one property: the converted amount is computed in the form and written as
the ordinary group-currency amount, so nothing downstream of the write knows a conversion happened.
The provenance columns ride along unread. That keeps the RPCs, the derived `group_shares_summary`
table and every balance path exactly as they are.

The editor is where the work is. Amount entry today goes through a keypad and a decimal input that
[multi-currency-core](multi-currency-core.md) has already made currency-aware — here they need to
follow the *entry* currency while the preview and the stored value follow the *group* currency. The
itemized editor complicates this: an expense has many entries and a live running total, so the
conversion has to apply consistently across entries rather than per keystroke on one field.

Receipt scanning is currency-blind today — its parser strips only `€` and `$`, so a CHF or GBP
receipt will not yield amounts. That is a pre-existing limitation, not a regression this feature
introduces, but it will look like one to a user scanning a receipt abroad; decide at pull time
whether to widen the regex here or leave it.

- Likely touchpoints: new Supabase migration, `lib/pages/expenses/data/expense_model.dart`,
  `expense_entry_model.dart` and `expense_repository.dart`,
  `lib/pages/expenses/presentation/expense_detail.dart`, `expense_entry_widget.dart` and
  `expense_detail_read.dart`, `lib/provider.dart` (sticky-rate preference),
  `lib/pages/groups/` (currency picker lock), both ARB files
- Depends: multi-currency-group
- Parallel-with: —

status: planned
