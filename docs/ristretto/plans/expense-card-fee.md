# expense-card-fee

## Spec
- Source: idea — a live bug walk, 2026-09-17: a 5 170 Ft receipt in a EUR group settled at €14.17 by
  ECB reference while the card statement said €14.32. Design brief:
  [expense-card-fee-design-brief](../expense-card-fee-design-brief.md).
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
    `expense_editor_rate_prefill_test.dart` and `expense_editor_currency_rate_test.dart` still
    passes, **rewritten only to reach the rate field through `showConversionSheet`**. Each test keeps
    its behavioural content unchanged — same inputs, same converted amounts, same blocked-save states,
    same assertion count; the only permitted edit is opening the sheet before touching the field.
    Deleting or weakening an assertion is a contract breach, not a rewrite.
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
  - `showConversionSheet(BuildContext, {required Currency entryCurrency, required Currency
    groupCurrency, required TextEditingController rateController, required Listenable rateState,
    required ConversionSheetData Function() data, required VoidCallback onRateTyped, required
    VoidCallback onClearSavedRate, required VoidCallback onEditCardFee}) -> Future<void>`
    (`lib/widgets/restyle/expense_picker_sheets.dart`) — the rate/fee/source sheet. `data` is a
    getter, not a value: the sheet is a separate route and re-reads the editor's state on every
    rebuild, driven by `rateState`.
  - `ConversionSheetData` + `ConversionSheet`
    (`lib/widgets/restyle/expense_picker_sheets.dart`) — the sheet's data carrier and its body.
    Both public: `ConversionSheetData` is a required parameter type, and `ConversionSheet` is what
    the test harness's `inConversionSheet` scopes a finder to. The file stays free of
    `provider.dart`: everything Riverpod-shaped arrives through `data` or a callback.
  - `showCardFeeSheet(BuildContext, {double? initial}) -> Future<double?>` +  `CardFeeSheet`
    (`lib/pages/settings/card_fee_sheet.dart`) — the fee entry sheet, shared by Settings and the
    conversion sheet. It writes the preference itself, so there is one write site.
  - `formatPercentValue(double percent, Locale locale) -> String` (`lib/helper/helper.dart`) —
    pure; `1.4` in `en`, `1,4` in `de`. Memoized per locale. NOT written into the original
    `Provides:`, but public and depended on by three surfaces.
  - `parseCardFeePercent(String? text) -> double?` (`lib/helper/helper.dart`) — pure; null for
    blank, unparseable or negative, and **0 is valid**. Distinct from `parseConversionRate`, whose
    non-positive parse must map to null. Also absent from the original `Provides:`.
  - Test harness, exported from `test/widgets/expense_editor_currency_rate_test.dart` for every
    suite that drives the editor: `StubLookup`, `openConversionSheet`, `closeConversionSheet`,
    `inConversionSheet`, `itemizedExpense`, and `pumpEditorWithSaveSeam`'s new `initialAmount`.
- Consumes: `Currency`, `roundCurrency`, `formatMoney`, `formatAmountOnly`
  ([multi-currency-core](multi-currency-core.md)); `convertToGroupCurrency`, `stickyRate`,
  `setStickyRate` ([multi-currency-expense-rate](multi-currency-expense-rate.md));
  `fetchRate`, `RateQuote`, `RateLookup`
  ([multi-currency-rate-source](multi-currency-rate-source.md)); plus `formatRate`,
  `parseConversionRate` and `ExpenseConversion`, which exist in the built code but were never written
  into a sibling's `Provides:` — noted rather than blocking, since every prerequisite is `done`.
- Decisions:
  - The fee is a **device preference**, never a column on `expense` -> `conversion_rate` has never
    meant "the ECB rate"; it means "the rate this expense used", so a fee folded into it is the column
    doing its job. A column would cost a hand-applied migration on the self-hosted instance
    ([manual-checks.md](../../manual-checks.md)) plus the RPC re-stated, to buy the read view printing
    "0.002741 + 1.4%" instead of "0.0027789".
  - The fee applies **only** to `_RateOrigin.prefilled` -> this is what makes double-application
    impossible without a schema change. A typed rate, a rate frozen on a saved expense and a sticky
    rate are all `_RateOrigin.user` and are the user's own number.
  - A fee change **re-applies to the retained fetched base rate** and never refetches -> the rate for a
    given pair and date is immutable, so a refetch would return the same number; and the flight's only
    refetch trigger is a date change ([multi-currency-rate-source](multi-currency-rate-source.md)).
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
  - **Ruling, Jakob, 2026-09-17** — the density move wins over the untouched-suites criterion. The
    two were mutually exclusive as originally written: 23 of the 38 tests in the two rate suites drive
    `expense_rate_field` / `expense_rate_reset` / `expense_rate_preview` / `expense_rate_prefill_date`
    on the main screen with no sheet open, so moving the field necessarily edits them. The suites are
    rewritten to open the conversion sheet first and keep every assertion's meaning, which preserves
    the no-fee regression protection those criteria exist for. This resolves the block recorded on the
    roadmap the same day.
  - The rate field leaves the main screen in **both** layouts -> `_buildCurrencyAndRate()` already
    serves Quick and Itemized, and two divergent conversion UIs would be worse than the cramping.
  - The expense **read view is unchanged** -> it shows the effective rate, which is the rate the
    expense used. Nothing there needs to know a fee was in it.
  - **No change** to the conversion arithmetic, the provenance columns, `save_expense_all`, or any
    balance path -> the largest risk reduction available in this flight is still not touching the
    functions that live only on the self-hosted instance.
  - The fee is **not** user-scoped state -> it is a fact about the device's owner's card, so it
    survives a user switch exactly as `ThemeModeNotifier` and `NotificationsEnabledNotifier` do.
  - [ ] the Contract originally held two mutually exclusive `[auto]` criteria — the rate field leaving the editor's main screen, and the two rate suites passing **unedited**. 23 of their 38 tests drive `expense_rate_field` / `expense_rate_reset` / `expense_rate_preview` / `expense_rate_prefill_date` on the main screen with no sheet ever opened, so the two could not both hold. The first planner run returned `blocked` on it and the roadmap row was set `blocked`; Jakob ruled the same day that the density move wins and the suites are rewritten to reach the field through `showConversionSheet`, keeping every assertion's behavioural meaning. The ruling is recorded in `Decisions:` above and the amended criterion in `Acceptance:`.
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
    [COMPONENTS.md](../../../design_handoff/COMPONENTS.md) §3.
  - Settings: a `Foreign transaction fee` row in the Preferences list plus the shared fee entry sheet.
  - l10n: every new key in `app_en.arb` and `app_de.arb`, including the locale-correct percent form.
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

## Evidence

Gates, on the whole repo (`gate.js verify`): **lint ✓ test ✓** — `flutter analyze` clean,
1609 tests pass. `dart format --output=none --set-exit-if-changed` over all 19 touched Dart
files: `Formatted 19 files (0 changed)`.

**36 new tests**, and the 38 pre-existing tests in the two rate suites preserved.

| criterion | how it was proven |
|---|---|
| fetched rate x fee -> 14.37; no fee -> 14.17 | `expense_editor_card_fee_test.dart` tests 1-2 drive 5 170 HUF through the editor at a fetched base of 0.0027405 and read BOTH the conversion row (`EUR 14.37` / `EUR 14.17`) and the save seam's `conversion!.toLedger(5170)`. `card_fee_test.dart` test 1 pins the arithmetic: `applyCardFee(0.0027405, 1.4)` = 0.002778867, `formatRate` of it = `0.00277887`. |
| a typed rate is never modified | `expense_editor_card_fee_test.dart` test 3 — typing 0.0027699 with a 1.4% fee saved stores 0.0027699 and settles 14.32, and no fee chip is claimed. |
| a sticky prefill is never modified | test 4 — the field reads `0.0027699` exactly, `lookup.calls` is empty, and the chip reads `expenseTypedRateChip`. |
| reopen + re-save applies the fee no second time | test 5 — a saved JPY expense re-saves at rate 0.0058, rateDate 2026-08-16, ledger 17.40, with `lookup.calls` empty. |
| a fee change recomputes and issues no request | test 6 — setting 1.4% through the sheet's fee row moves the field 0.0027405 -> 0.00277887 with `lookup.calls` still `hasLength(1)`; clearing it returns the field to 0.0027405, still one call. |
| ...and any other field still triggers no fetch | **existing** `'editing another field neither refetches nor moves the rate'` (`expense_editor_rate_prefill_test.dart`), cited not duplicated. |
| 0 == no fee saved | `expense_editor_card_fee_test.dart` test 7 (seeded `'0'`: row reads EUR 14.17, no chip, field is the untouched base), `card_fee_test.dart` test 2 (`applyCardFee` with 0/null/NaN/infinity), `provider/card_fee_test.dart` (a 0 clears the preference rather than storing a zero). |
| no-fee behaviour is exactly today's | the 38 preserved tests in `expense_editor_rate_prefill_test.dart` (16) and `expense_editor_currency_rate_test.dart` (22). They went red the moment the field left the main screen — 23 of 38 — which is the proof it actually left; they were then rewritten only to reach it through `showConversionSheet`, keeping every assertion's meaning and count. One test GAINED an assertion (`'switching back clears the rate field and the rate row'` now also asserts the conversion row is gone, without which it would have been vacuous). |
| no rate field on the main screen, both layouts | `expense_conversion_card_test.dart` tests 1-3: Quick and Itemized both assert the field, `expenseRateRequired` and Clear-saved-rate absent while the two rows are present and each is exactly one `InkWell`; test 3 then opens the sheet and finds the field and Reset there. |
| the row states the amount + provenance chips | tests 4-7: `EUR 9.43` under `expense_conversion_amount`, the source chip carrying the rate's own effective date (the Tuesday, not the expense's Wednesday), the fee chip present only for a non-zero fee on a fetched rate, and `expenseTypedRateChip` for a typed one. |
| the needs-a-rate state, save still blocked | `expense_conversion_card_test.dart` test 8 — `expense_conversion_rate_needed` present, `expense_conversion_amount` absent, `expenseNoRateChip` shown, and tapping save raises the refusal with `ExpenseDetail` still mounted: no write, no pop, no 1:1 fallback. Plus **existing** `'saving a foreign-currency expense with no rate is REFUSED'`. |
| the source line states the base rate whenever a fee was applied | `expense_conversion_card_test.dart`: `expenseConversionSourceLine('30 Jun 2026', '0.9432')` on screen while the field holds `0.956405`; absent with no fee. |
| the fee reads and writes per locale | `card_fee_test.dart` test 3 (`1.4 %` in en, `1,4 %` in de, both parsing back to 1.4) and `card_fee_sheet_test.dart` (the field seeds `1.4` in en, `1,4` in de). |
| survives a restart and a user switch | `provider/card_fee_test.dart` tests 3-4 (a stored fee hydrates into a fresh container; the first read after app start sees it, hydration awaited not raced), plus the extended device-scoped test in `auth_switch_invalidation_test.dart`, where a third counted provider now proves `signedOut` does not rebuild the fee. |
| every new l10n key in both ARBs | verified directly rather than by the test the Contract cited: **568/568 keys present in both** `app_en.arb` and `app_de.arb`, all 15 new keys among them with distinct German. See the first open finding — the Contract's "already enforced repo-wide by the ARB parity tests" premise is false; each `test/l10n_*_test.dart` pins a hard-coded list for its own feature. Four of the new strings ARE pinned as real German by `card_fee_test.dart` test 4. |
| `dart format`, `flutter analyze`, `flutter test` | the gates, above. |

Two blocking findings were raised in round 1 and both were verified before fixing, not taken on
trust:

1. `dart format` did not pass over 6 touched files — confirmed by running it. Fixed. (The repo-wide
   `dart format lib/ test/` used to fix it reformatted ~115 unrelated files, all of which were
   reverted; round 2 confirmed the diff is back to this feature's 23 files and nothing of the
   feature was lost.)
2. **A typo silently deleted a saved fee.** `_save()` mapped unparseable input to `0`, which
   `setCardFeePercent` collapses into `clearCardFee`. Reachable in `de` only: the field is seeded
   `"1,4"`, `DecimalTextInputFormatter.isDoubleDot` counts only `.` so `"1,4."` is accepted, and
   `double.tryParse("1.4.")` then returns null — verified by running both in Dart. In `en` the
   formatter rejects `"1.4."` itself (three parts), so the bug was German-only. Fixed: blank is now
   the only route to 0; anything else that will not parse shows `cardFeeSheetInvalid` and keeps the
   stored value. Pinned by `test/widgets/card_fee_sheet_test.dart`, which asserts both the raw
   preference and the re-hydrated notifier still read 1.4.


No migration was authored and none is needed: nothing here touches the database,
`save_expense_all`, the `exchange-rate` Edge Function, or any balance path. `Manual-Checks: —`
stands, and `docs/ristretto/manual-checks.md` is unmodified.

review: notes-only · rounds: 2 · open: 0 block, 3 note, 3 lean
tier: normal

## Open findings

Round 2's findings, recorded rather than fixed. None blocks.

- `note` · `lib/pages/settings/card_fee_sheet.dart:62` · `didChangeDependencies` re-seeds the field
  from `widget.initial` whenever it is empty, so an inherited-widget change while the sheet is open
  with a deliberately-cleared field (system dark-mode flip on `ThemeMode.system`, locale change)
  restores the old fee and Save then stores it instead of clearing; not blocking because the
  restored text is visible in the field before Save and no stored value changes without the user
  seeing it · guard the seed with a one-shot bool `_seeded`
- `note` · `test/widgets/expense_conversion_card_test.dart:56` · `expectTwoTapTargets` still doesn't
  prove its docblock's "and that there is no THIRD" — it only checks each of the two keyed rows
  holds exactly one `InkWell`, so a third tap target added as a sibling in the same `SoftCard`
  passes; not blocking because the shipped card genuinely has two · key the merged card and assert
  `findsNWidgets(2)` for `InkWell`s descending from it
- `note` · `docs/ristretto/plans/expense-card-fee.md:~55` · the 15 new l10n keys have no parity test
  — `test/l10n_*_test.dart` each pin a hard-coded key list for their own feature, so the "already
  enforced repo-wide" premise is false (correctly acknowledged in round 1); not blocking because I
  checked the ARBs directly: 568/568 keys present in both, so the criterion itself is met · record
  the direct check in Evidence, or add these keys to a parity list
- `lean` · `test/widgets/expense_conversion_card_test.dart:210` · "a fee saved but a TYPED rate" is a
  strict subset of `expense_editor_card_fee_test.dart`'s "a rate the user TYPED is never modified by
  the fee" — same pump, same pick, same typed rate, same chip assertion, and the latter also pins
  the saved rate and ledger amount; the self-containment reasoning holds for the presence/absence
  pair but not for this third case · delete it and let the money test carry it
- `lean` · `test/widgets/card_fee_sheet_test.dart:171` · "the field seeds the stored fee in de,
  comma-separated" repeats the `expect(_fieldText, '1,4')` already made inside the typo regression
  test at line ~120, and the locale rendering is pinned at the pure level in
  `test/helper/card_fee_test.dart` · drop it
- `lean` · `test/widgets/setting_page_test.dart:34` · `_FakeCardFeeNotifier.build()` does not
  initialize the base class's `late final _hydration`, so any later test awaiting `hydrated` through
  this fake throws `LateInitializationError` rather than resolving · assign it a `Future.value()` in
  the override

One round-1 lean was deliberately left and round 2 accepted the reasoning for two of its three
cases: the fee chip's presence/absence is the conversion card's own criterion, while the card-fee
suite asserts it as a side-check inside money tests, so neither suite was thinned. Round 2 narrowed
the objection to the third case only, recorded above.
