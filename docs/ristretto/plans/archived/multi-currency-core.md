# multi-currency-core — Currency value object + currency-aware money pipeline

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08; flight replanned 2026-08-11 against
  competitor + user-sentiment research — see `Decisions` and the flight note in
  [multi-currency-group](multi-currency-group.md))
- Flight: multi-currency
- Goal: Every amount in the app is rounded, formatted and entered according to an explicit `Currency`
  (including its decimal-digit count) instead of an implicit hardcoded EUR with 2 decimals. Nothing
  user-visible changes yet — every caller passes EUR — but the whole money pipeline becomes
  currency-parameterized.

## Rebase note — written against origin/main, corrected 2026-08-15
This plan was authored against `origin/main`, which does not contain the multi-currency work that
shipped on `feature/brew-2026-07-12` (`47c5a6d`, `9349e38`). Re-verified against the real tree; the
feature survives almost intact, with these corrections:

- **Already true, do not treat as work:** no user-visible hardcoded `€` remains — every match in
  `lib/` is a doc comment, and `helper.dart` already replaced the generated `toCurrency` that baked
  the glyph into ARB metadata. The three literal `Text("€")` widgets are gone.
- **`MoneyText` already takes a currency**, but as a `String currencyCode` defaulting to
  `kDefaultCurrencyCode` (`money_text.dart:36`). This feature migrates that to the `Currency` value
  object and adds `CurrencyScope`; it does not introduce currency-awareness from nothing.
- **Three dead l10n keys, not four** — `toCurrencyNoPrefix` is already gone. `groupDisplayAmount`,
  `groupDisplaySumAmount` and `totalExpensesAmount` remain, still with zero Dart callers.
- **Still exactly as described:** `roundCurrency` hardcodes `(value * 100) / 100`
  (`helper.dart:32`), `_kSettledThreshold = 0.01` (`group_list_view_model.dart:6`),
  `_kSettledEpsilon = 0.005` (`payment_view_model.dart:23`), the inline `< 0.01`
  (`friendship_repository.dart:67`), and `toStringAsFixed(2)` at ~25 sites.

## Contract
- Acceptance:
  - A `Currency` exists for every code in the curated list and exposes its ISO 4217 code, display
    symbol and `decimalDigits`. `Currency.fromCode('JPY').decimalDigits` is 0;
    `Currency.fromCode('EUR').decimalDigits` is 2. An unknown or null code resolves to EUR rather
    than throwing.
  - The curated list is exactly the ECB/Frankfurter reference set (the ~30 codes the rate source in
    [multi-currency-rate-source](multi-currency-rate-source.md) can quote), so every listed currency
    is convertible later. It contains at least EUR, USD, GBP, CHF and JPY.
  - Rounding is currency-aware: rounding 2500.4 in JPY yields 2500, rounding 2500.6 in JPY yields
    2501, and rounding 12.345 in EUR yields 12.35. The existing 2-decimal behaviour is preserved
    exactly for every 2-decimal currency (no existing money-math test changes its expected value).
  - The settled-balance predicate unified by [settle-residue](settle-residue.md) gains a currency and
    is true below half a minor unit: true for 0.4 JPY, false for 0.6 JPY, true for 0.004 EUR, false
    for 0.006 EUR. Every call site already routes through that one predicate by the time this feature
    starts, so this is a signature widening, not a second sweep.
  - Formatting is currency- and locale-aware: the same amount renders "¥3,000" in `en` and "3.000 ¥"
    in `de` for JPY, and "$1,234.56" / "1.234,56 $" for USD. No fractional digits are ever rendered
    for a 0-decimal currency.
  - No user-visible amount anywhere renders a hardcoded currency glyph. Searching `lib/` for `€`
    outside doc comments returns no matches. This already holds — keep it as a regression guard, and
    do not spend a unit on it.
  - The expense-editor hero amount renders through the formatting pipeline rather than
    `toStringAsFixed(2)`, so a German user sees "12,50" and not "12.50".
  - Amount entry respects the currency's decimal digits: the keypad accepts no fractional part for
    JPY and two fractional digits for EUR. *(Amended during build — see the amount-entry decision
    below: there is no money-carrying decimal text input left in the app, so the keypad is the whole
    of amount entry.)*
  - The three l10n keys with zero Dart callers (`groupDisplayAmount`, `groupDisplaySumAmount`,
    `totalExpensesAmount`) are deleted rather than migrated.
  - `flutter analyze` and `flutter test` pass, with new tests covering rounding, the settled
    predicate and formatting for at least one 0-decimal and one 2-decimal currency in both locales.
- Provides:
  - `Currency` (`lib/helper/currency.dart`) — `Currency.fromCode(String? code) -> Currency` (EUR
    fallback), `.code -> String`, `.symbol -> String`, `.decimalDigits -> int`,
    `.minorUnit -> double`, `.settledEpsilon -> double` (half a minor unit), equality/hashCode by
    `code`
  - `kSupportedCurrencies -> List<Currency>` — the 31-code ECB/Frankfurter reference set
  - `roundCurrency(double value, Currency currency) -> double` (`lib/helper/helper.dart`)
  - `isSettled(double amount, Currency currency) -> bool` (`lib/helper/helper.dart`) — widened from
    `settle-residue`'s currency-blind predicate
  - `kSettledEpsilon -> double` (unchanged, 0.005) and `kMaxSettledEpsilon -> double` (new — the
    largest `settledEpsilon` across `kSupportedCurrencies`, 0.5 from JPY/ISK/KRW)
  - `formatMoney(double amount, Currency currency, Locale locale) -> String` and
    `formatAmountOnly(double amount, Currency currency, Locale locale) -> String` (bare number, no
    symbol) (`lib/helper/helper.dart`)
  - `AppLocalizations.toCurrency(double amount, String? currencyCode)` — kept its existing `String`
    signature (per the Rebase note) but its body now routes through `formatMoney` +
    `Currency.fromCode`, so all ~35 existing call sites became decimal-digit-correct with zero edits
  - `CurrencyScope` (`lib/widgets/currency_scope.dart`) — inherited widget;
    `CurrencyScope.of(BuildContext) -> Currency` (EUR when unmounted); mounted at the app root in
    `lib/navigation.dart` with `Currency.eur`
  - `MoneyText(double amount, {Currency? currency, ...})` (`lib/widgets/restyle/money_text.dart`) —
    `currencyCode` migrated from `String` to `Currency?`, falling back to `CurrencyScope.of` when
    omitted
  - `GroupRepository.narrowToStatus(List<Group> groups, String statusFilter) -> List<Group>`
    (`lib/pages/groups/data/group_repository.dart`) — new pure function; applies `isSettled` per row
    to narrow the server's superset query (see Decisions)
  - `KeypadAmount.fromText`/`AmountKeypadSheet` currency-aware `decimalDigits` (0 for JPY-class
    currencies, inert decimal key) (`lib/pages/expenses/data/keypad_amount.dart`)
  - `DecimalTextInputFormatter(decimalRange: ...)` — `decimalRange` is now honoured for real (was
    dead), and `decimalRange: 0` rejects the separator outright; no currency constructor was added
    (see Decisions)
- Consumes: —
- Decisions:
  - Money stays a Dart `double`; only the decimal-digit count becomes currency-aware -> migrating to
    integer minor units is a much larger refactor and is the direct cause of the
    "19.99 saves as 19, exports as 0.19" class of bug seen in Spliit. Keep the representation,
    fix the exponent.
  - `MoneyText`'s existing `String currencyCode` becomes a `Currency`, backed by a `CurrencyScope`
    default rather than the current `kDefaultCurrencyCode` constant -> many of its ~39 construction
    sites (balance pills, keypad displays, stat tiles, month sheets) have no `Group` in scope, which
    is exactly why the default exists today; the scope keeps them working while making the default
    inherited instead of hardcoded.
  - Curated list is pinned to the ECB/Frankfurter set -> guarantees every currency the user can pick
    is one we can later fetch a rate for, and avoids shipping a picker full of dead ends.
  - No 3-decimal currency (KWD/BHD/JOD) appears in the list, because none is in the ECB set. The
    implementation still handles a general exponent; the list simply exercises only 0 and 2.
  - `roundCurrency` keeps its name and gains a required `Currency` -> a compile error at every call
    site is the cheapest way to guarantee none is missed.
  - **Amount entry is keypad-only; `DecimalTextInputFormatter` gets no currency constructor**
    (decided during build, from review) -> every money field in the app opens `AmountKeypadSheet`
    (F158), which takes its precision from the group's `Currency`. The only surviving
    `DecimalTextInputFormatter` wiring in `lib/` is the per-member **percentage** field
    (`decimalRange: 1`). A `forCurrency` constructor was added and had zero callers, which made the
    "decimal text input" half of the entry criterion true only of its own unit test; it is dropped.
    What survives is the real fix underneath it: `decimalRange` is finally honoured (the body
    hardcoded `dotIndex + 3`, so `decimalRange: 1` let two digits through), and `decimalRange: 0`
    rejects the separator outright. If a money text field ever comes back, that is the moment to add
    the currency constructor — with a caller.
  - **The server-side balance predicates stay currency-blind and are narrowed on the client**
    (decided during build, from review) -> `GroupRepository.fetchData` filters
    `total_share_amount` on a *referenced* table while `currency_code` lives on the parent row, so
    PostgREST genuinely cannot ask a row for its currency there. Rather than leave the threshold
    pinned to EUR (which put a JPY group with |net| in `[0.005, 0.5)` — a settled ¥0 hero — on the
    active side), the query bounds are now a deliberate **superset**: active uses `kSettledEpsilon`
    (the smallest supported epsilon), done uses `kMaxSettledEpsilon` (the largest, 0.5), and
    `GroupRepository.narrowToStatus` then applies the one `isSettled(amount, currency)` per row. EUR
    results are byte-identical, so no existing caller moves.
- Units:
  - `Currency` value object + curated registry (code, symbol, decimal digits) with EUR fallback.
  - Currency-aware rounding; replace the hardcoded `/100`, and widen the settled predicate inherited
    from [settle-residue](settle-residue.md) to take a `Currency`.
  - Currency-aware amount entry: keypad max decimal digits, the decimal text input formatter, and
    expense serialization's `toStringAsFixed(2)`.
  - Formatting pipeline: delete the three dead l10n keys; normalize the one key that uses `symbol`
    where the rest use `name`.
  - `CurrencyScope` + migrate `MoneyText.currencyCode` from `String` to `Currency`, mounted at the
    app root with EUR so every existing call site keeps working unchanged.
  - Replace the remaining `toStringAsFixed(2)` sites, including the expense-editor hero.
- Blockers: —

## Approach
Introduce `Currency` as a plain value object next to the existing `ExpenseCategory` enum pattern
(which already has the `fromString` shape we want), and a curated const registry mirroring how
`kGroupColorPalette` is declared in `constants.dart`. Everything else in this feature is a mechanical
sweep behind that type.

The formatting layer is already currency-parameterized: `helper.dart` replaced the generated
`toCurrency` that baked `€` into ARB metadata, and money strings now take a currency code. So the
wide sweep this plan originally described is **already done** — what remains is replacing the loose
`String` code with the `Currency` type so decimal digits travel with it. `MoneyText` is the choke
point for widget-side rendering; `CurrencyScope` exists so the ~39 call sites that have no group in
scope keep working, and so [multi-currency-group](multi-currency-group.md) can later re-mount the
scope at the group route boundary as a one-line change.

Ship this with every caller passing EUR. The only user-visible difference is one bug fix: the
expense-editor hero stops showing a period-separated amount to German users.

- Likely touchpoints: `lib/constants.dart`, `lib/helper/helper.dart`, `lib/l10n/*.arb` (+ regenerated
  l10n), `lib/widgets/restyle/money_text.dart`, `lib/widgets/.../keypad_amount.dart` and
  `decimal_text_input_formatter.dart`, `lib/pages/expenses/presentation/expense_detail.dart` and
  `expense_entry_widget.dart`, `lib/pages/groups/presentation/group_list_view_model.dart`,
  `lib/pages/friends/data/friendship_repository.dart`, `lib/pages/groups/presentation/payment_view_model.dart`
- Depends: settle-residue *(its **client half** only — the single settled predicate. This feature does
  not need settle-residue's deferred server-side exact-settlement fix, so it is **not** blocked if
  that half is waiting in [manual-checks.md](../../manual-checks.md). Pull this as soon as the predicate is
  unified.)*
- Parallel-with: expense-notification-route, expense-editor-edit-labels

## Evidence

- **`Currency` exists for every curated code, EUR fallback for unknown/null** —
  `test/helper/currency_test.dart`: `resolves every code in the curated list`,
  `JPY has 0 decimal digits, EUR has 2`, `an unknown or null code falls back to EUR instead of
  throwing`.
- **Curated list is exactly the 31-code ECB/Frankfurter set, contains EUR/USD/GBP/CHF/JPY, no
  duplicates** — `test/helper/currency_test.dart`: `exactly the 31 ECB reference codes, no more and
  no fewer`, `contains at least EUR, USD, GBP, CHF and JPY`, `no code appears twice`, `every entry
  exposes a non-empty symbol and a sane exponent`, `the list exercises exactly the 0- and 2-decimal
  cases`.
- **Currency-aware rounding, 2-decimal behaviour unchanged** —
  `test/helper/helper_test.dart` group `roundCurrency is currency-aware`: `roundCurrency(12.345,
  EUR) == 12.35`, `roundCurrency(2500.4, JPY) == 2500`, `roundCurrency(2500.6, JPY) == 2501`, plus
  every pre-existing 2-decimal case (`0.1+0.2`, `100/3`, `200/3`, `-200/3`, `12.34`) re-asserted
  byte-identical against `Currency.eur`.
- **Settled predicate widened, currency-aware** — `test/helper/helper_test.dart` group `isSettled is
  currency-aware`: `isSettled(0.4, JPY) == true`, `isSettled(0.6, JPY) == false`,
  `isSettled(0.004, EUR) == true`, `isSettled(0.006, EUR) == false` (and the symmetric negative
  cases).
- **Formatting is currency- and locale-aware, no fractional digits for 0-decimal currencies** —
  `test/pages/groups/multi_currency_core_test.dart` group `formatMoney is currency- and
  locale-aware`: `JPY renders "¥3,000" in en and "3.000 ¥" in de`, `USD renders "$1,234.56" in en and
  "1.234,56 $" in de`, `EUR is unchanged in both locales`, `no 0-decimal currency ever renders a
  fractional part`; group `formatAmountOnly renders the bare number in the locale`: `12.5 in EUR is
  "12.50" in en and "12,50" in de`, `3000 in JPY carries no fractional part`.
- **`AppLocalizations.toCurrency` routes through the new pipeline with zero call-site edits** —
  `test/pages/groups/multi_currency_core_test.dart` group `AppLocalizations.toCurrency routes through
  the currency`: `a 0-decimal code loses its fractional digits`, `an unknown code falls back to EUR
  instead of throwing`, `2-decimal formatting is unchanged`.
- **Dead l10n keys deleted** — `test/pages/groups/multi_currency_core_test.dart` group `dead l10n
  keys` asserts `groupDisplayAmount` and `groupDisplaySumAmount` have no remaining Dart references
  (`totalExpensesAmount` was already gone, per the plan's Rebase note).
- **No hardcoded `€` regression guard** — `test/pages/groups/multi_currency_core_test.dart`: `no
  user-visible amount renders a hardcoded € (regression guard)`.
- **Expense-editor hero renders through the formatting pipeline (German gets a comma, not a
  period)** — `test/widgets/expense_editor_amount_locale_test.dart`.
- **`CurrencyScope` + `MoneyText` migration** — `test/pages/groups/multi_currency_core_test.dart`
  group `CurrencyScope + MoneyText`, plus `test/widgets/expense_entry_widget_test.dart` and
  `test/widgets/expense_picker_sheets_test.dart` (updated for the `Currency` param).
  `CurrencyScope` is mounted at the app root in `lib/navigation.dart` with `Currency.eur`, so every
  existing call site keeps working unchanged.
- **Amount entry respects the currency's decimal digits (keypad)** —
  `test/model/keypad_amount_test.dart` (currency-aware `decimalDigits`, JPY's decimal key inert).
- **`decimalRange` on `DecimalTextInputFormatter` is honoured for real, `decimalRange: 0` rejects
  the separator** — `test/widgets/decimal_text_input_formatter_test.dart`: `decimalRange: 0 rejects
  both separators outright`, `decimalRange: 1 blocks a second fractional digit`, `a typed comma is
  normalized to a dot`, `a second separator is rejected`. (No `forCurrency` constructor exists — see
  the amount-entry Decision above.)
- **Server-side balance predicate stays a deliberate superset; `narrowToStatus` makes the real,
  currency-aware decision per row** — `test/model/group_repository_test.dart`: assertions that the
  query bounds sit in `[kSettledEpsilon, kMaxSettledEpsilon]` and `kMaxSettledEpsilon ==
  Currency.jpy.settledEpsilon == 0.5`, plus the `GroupRepository.narrowToStatus` group covering
  active/done narrowing per-currency and the EUR-byte-identical case.

### Gate summary
- `flutter analyze` — clean, no issues.
- `flutter test` — 1219 passed, 0 failed. Baseline at HEAD `0582263` (before this feature) was 1140;
  the implementer added 53 tests to reach 1195, the two review rounds' fixes added 24 more.

### Review verdict
Two rounds. Round 1 raised 5 bugs and 2 lean/simplification points, all fixed — including the two
Decisions recorded above (dropping the callerless `DecimalTextInputFormatter.forCurrency` and
narrowing the server query to a deliberate superset resolved per-row by `narrowToStatus`). Round 2
verdict: `review: clean`.

### Known follow-up (not fixed, surfaced by the implementer)
`lib/pages/expenses/data/expense_deletion_impact.dart`'s `confirmMessage` and a few other minor
callers still take a raw `currencyCode` String rather than `Currency`. Left as-is — out of scope for
this feature's contract, worth a small follow-up sweep whenever those call sites are next touched.

status: done
