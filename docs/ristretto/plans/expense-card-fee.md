# expense-card-fee — A card's foreign-transaction fee, on the rates Deun looks up

## Spec
- Source: idea — a live bug walk, 2026-09-17: a 5 170 Ft receipt in a EUR group settled at €14.17 by
  ECB reference while the card statement said €14.32. Design brief:
  [expense-card-fee-design-brief](expense-card-fee-design-brief.md).
- Flight: multi-currency
- Goal: let a user record their card's foreign-transaction fee once, have it ride on every rate Deun
  fetches, and collapse the editor's currency/rate block into one card so the fee has somewhere to live.

## Contract
- Acceptance:
  - [auto] With a 1.4% fee saved, a foreign-currency expense whose rate was **fetched** converts at
    base × 1.014: 5 170 HUF in a EUR group at a fetched base of 0.0027405 previews and saves
    **€14.37**. The same expense with no fee saved previews and saves **€14.17**.
  - [auto] A rate the user **typed** is never modified: with a 1.4% fee saved, typing 0.0027699
    previews and saves €14.32, not €14.37.
  - [auto] A **sticky** rate prefill is not modified by the fee either — it is a rate the user typed
    on an earlier expense.
  - [auto] Reopening a saved converted expense and re-saving it without touching the rate stores the
    same rate and the same converted amount, with any fee saved. The fee is never applied twice.
  - [auto] Changing the fee while the editor is open recomputes the displayed rate from the base rate
    already fetched, and issues **no** new rate request. The existing date-change-only refetch rule is
    unaffected: editing any other field still triggers no fetch.
  - [auto] A fee of 0 is indistinguishable from no fee saved: no fee chip, and the rate in the field
    equals the fetched base.
  - [auto] With no fee saved, the foreign-currency editor behaves exactly as it does today — same
    converted amount for the same inputs, no new chip, no new prompt. Every existing test in
    `expense_editor_rate_prefill_test.dart` and `expense_editor_currency_rate_test.dart` passes
    **unedited**.
  - [auto] The editor's main screen carries no rate text field. In the foreign-currency state the
    currency row and the conversion row are the only two tap targets in that block; the rate field,
    its helper text and "Clear saved rate" are reachable only from the conversion sheet. This holds in
    **both** the Quick and Itemized layouts.
  - [auto] The conversion row states the converted amount in the group's currency plus its provenance:
    a source chip carrying the rate's effective date, and a fee chip **only** when a non-zero fee was
    applied to a fetched rate.
  - [auto] When no rate is available for the expense's date, the conversion row shows the
    needs-a-rate state and the save stays blocked — today's `expenseRateRequired` behaviour, moved but
    not weakened. There is still no implicit rate and no 1:1 fallback, with or without a fee.
  - [auto] The fee reads and writes per locale: 1.4 renders `1.4 %` in `en` and `1,4 %` in `de`, and
    both forms parse back to the same stored number.
  - [auto] The fee survives an app restart, and survives a user switch on the same device — it is
    device-scoped, like theme mode and the notifications toggle.
  - [auto] Every new l10n key exists in both `app_en.arb` and `app_de.arb` — already enforced
    repo-wide by the ARB parity tests; must stay green, nothing new to write for it.
  - [auto] `dart format`, `flutter analyze` and `flutter test` pass.
- Provides:
  - `cardFeeProvider` / `CardFeeNotifier` (`lib/provider.dart`) — `cardFeePercent -> double?`,
    `setCardFeePercent(double percent) -> Future<void>`, `clearCardFee() -> Future<void>`,
    `hydrated -> Future<void>`; device-scoped, one value, excluded from
    `invalidateUserScopedProviders`
  - `kCardFeePrefKey -> String`
  - `applyCardFee(double baseRate, double? feePercent) -> double` (`lib/helper/helper.dart`) — pure;
    returns `baseRate` unchanged for a null, zero or non-finite fee
  - `showConversionSheet(BuildContext, {...}) -> Future<...>`
    (`lib/widgets/restyle/expense_picker_sheets.dart`) — the rate/fee/source sheet
  - `showCardFeeSheet(BuildContext, {double? initial}) -> Future<double?>` — the fee entry sheet,
    shared by Settings and the conversion sheet
- Consumes: `Currency`, `roundCurrency`, `formatMoney`, `formatAmountOnly`
  ([multi-currency-core](archived/multi-currency-core.md)); `convertToGroupCurrency`, `stickyRate`,
  `setStickyRate` ([multi-currency-expense-rate](archived/multi-currency-expense-rate.md));
  `fetchRate`, `RateQuote`, `RateLookup`
  ([multi-currency-rate-source](archived/multi-currency-rate-source.md)); plus `formatRate`,
  `parseConversionRate` and `ExpenseConversion`, which exist in the built code but were never written
  into a sibling's `Provides:` — noted rather than blocking, since every prerequisite is `done`.
- Decisions:
  - The fee is a **device preference**, never a column on `expense` -> `conversion_rate` has never
    meant "the ECB rate"; it means "the rate this expense used", so a fee folded into it is the column
    doing its job. A column would cost a hand-applied migration on the self-hosted instance
    ([manual-checks.md](../manual-checks.md)) plus the RPC re-stated, to buy the read view printing
    "0.002741 + 1.4%" instead of "0.0027789".
  - The fee applies **only** to `_RateOrigin.prefilled` -> this is what makes double-application
    impossible without a schema change. A typed rate, a rate frozen on a saved expense and a sticky
    rate are all `_RateOrigin.user` and are the user's own number.
  - A fee change **re-applies to the retained fetched base rate** and never refetches -> the rate for a
    given pair and date is immutable, so a refetch would return the same number; and the flight's only
    refetch trigger is a date change ([multi-currency-rate-source](archived/multi-currency-rate-source.md)).
    The editor therefore keeps the base rate alongside the effective one.
  - The fee multiplies the **raw** base rate before `formatRate` renders it -> `formatRate` keeps
    significant digits rather than six decimals (`fd90cd2`); applying the fee to an already-rendered
    rate would round twice.
  - **0 and unset are the same state** -> one way to express "no fee", so the chip has one condition
    and Settings has one empty value.
  - **One fee per device**, not per card, group or currency -> a card's markup does not vary by trip.
    Someone carrying two cards uses the manual rate field, which this feature leaves untouched.
  - Settings and the conversion sheet **write the same preference** -> two surfaces, one number.
    Settings is where it belongs; the sheet is where it is discovered.
  - The rate field leaves the main screen in **both** layouts -> `_buildCurrencyAndRate()` already
    serves Quick and Itemized, and two divergent conversion UIs would be worse than the cramping.
  - The expense **read view is unchanged** -> it shows the effective rate, which is the rate the
    expense used. Nothing there needs to know a fee was in it.
  - **No change** to the conversion arithmetic, the provenance columns, `save_expense_all`, or any
    balance path -> the largest risk reduction available in this flight is still not touching the
    functions that live only on the self-hosted instance.
  - The fee is **not** user-scoped state -> it is a fact about the device's owner's card, so it
    survives a user switch exactly as `ThemeModeNotifier` and `NotificationsEnabledNotifier` do.
- Units:
  - `CardFeeNotifier` + `kCardFeePrefKey` + the pure `applyCardFee`, modelled on `StickyRateNotifier`
    (hydrate behind a `Future`, synchronous read after `hydrated`, JSON-free single value).
  - Apply the fee on the prefill path in `ExpenseDetail._prefillRate`: retain the fetched base rate,
    write `applyCardFee(base, fee)` into the field, and re-apply on a fee change without refetching.
    The `_RateOrigin` guard is the whole of the invariant.
  - Replace `_buildCurrencyAndRate()` with the merged two-row card — currency row plus conversion row
    with amount and provenance chips — removing the rate field, helper, divider, preview row and
    "Clear saved rate" from the screen.
  - The conversion sheet: the conversion stated, the rate field, the source line naming the base rate
    and its effective date, the card-fee row, "Clear saved rate", Done. Built on `SheetScaffold` per
    [COMPONENTS.md](../../design_handoff/COMPONENTS.md) §3.
  - Settings: a `Foreign transaction fee` row in the Preferences list plus the shared fee entry sheet.
  - l10n: every new key in `app_en.arb` and `app_de.arb`, including the locale-correct percent form.
- Manual-Checks: —
- Blockers: —

## Approach

The feature is a preference, one pure function, and a redistribution of an existing widget's
contents. No database work, no Edge Function change, no new dependency.

The invariant carries the design: `_RateOrigin` already records where a rate came from, so gating the
fee on `prefilled` means a saved expense can never have the fee re-applied on reopen — which is what
removes the need for a stored column, and with it the migration. The editor gains one piece of state
it does not have today, the **base** rate behind the effective one, so that changing the fee
recomputes rather than refetches.

The density work is not cosmetic scope creep: the currency/rate block is already two cards and three
tap targets, and the fee cannot become a fourth. Moving the rate field into a sheet is what makes room,
and it is the same move the flight already made for the currency picker.

Watch for: `_switchBackToGroupCurrency` reads `_rate` directly, so it must read the **effective** rate
(what the expense would be saved with), not the base — otherwise switching back re-converts at the
wrong number. That function has a separate, known defect recorded in the brief's *Not done*; do not fix
it here, but do not make it worse.

- Likely touchpoints: `lib/provider.dart`, `lib/helper/helper.dart`,
  `lib/pages/expenses/presentation/expense_detail.dart`,
  `lib/widgets/restyle/expense_picker_sheets.dart`, `lib/pages/settings/setting.dart`,
  `lib/pages/settings/settings_sheets.dart`, `lib/l10n/*`
- Depends: —
- Parallel-with: —

status: planned
