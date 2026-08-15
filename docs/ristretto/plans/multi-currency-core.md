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
  - Amount entry respects the currency's decimal digits: the keypad and the decimal text input accept
    no fractional part for JPY and two fractional digits for EUR.
  - The three l10n keys with zero Dart callers (`groupDisplayAmount`, `groupDisplaySumAmount`,
    `totalExpensesAmount`) are deleted rather than migrated.
  - `flutter analyze` and `flutter test` pass, with new tests covering rounding, the settled
    predicate and formatting for at least one 0-decimal and one 2-decimal currency in both locales.
- Provides:
  - `Currency` — `Currency.fromCode(String? code) -> Currency` (EUR fallback), `.code -> String`,
    `.symbol -> String`, `.decimalDigits -> int`, `.minorUnit -> double`
  - `kSupportedCurrencies -> List<Currency>`
  - `roundCurrency(double value, Currency currency) -> double`
  - `isSettled(double amount, Currency currency) -> bool`
  - `formatMoney(double amount, Currency currency, Locale locale) -> String`
  - `CurrencyScope` — inherited widget; `CurrencyScope.of(BuildContext) -> Currency`
  - `MoneyText(double amount, {Currency? currency, ...})` — falls back to `CurrencyScope.of` when
    `currency` is omitted
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
  that half is waiting in [MANUAL_OPS.md](../MANUAL_OPS.md). Pull this as soon as the predicate is
  unified.)*
- Parallel-with: expense-notification-route, expense-editor-edit-labels

status: planned
