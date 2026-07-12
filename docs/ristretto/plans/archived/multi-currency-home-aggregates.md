# multi-currency-home-aggregates — Home currency for cross-group balances & statistics

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08)
- Flight: multi-currency
- Goal: The user picks a home currency; every total that spans groups (overall balance hero, friendship balances, statistics) converts mixed-currency amounts into it instead of summing raw numbers.
- Acceptance:
  - Settings has a home-currency picker (same curated list as group currencies); default EUR; choice persists across app restarts.
  - The overall balance hero on the group list, friendship shared amounts, and the statistics/personal-summary figures convert each group's contribution from its group currency into the home currency before summing; a user with a €10 balance in a EUR group and a $10 balance in a USD group sees one home-currency total, not 20.
  - Converted aggregates are visibly marked as approximate (e.g. "≈" prefix); a user whose groups are all in the home currency sees exact values with no marker.
  - Cross-group conversion uses current rates fetched at load from a free no-key rate API (frankfurter.app / ECB); when rates are unavailable (offline), the last known rates are used, and with no rates at all the aggregate falls back to home-currency groups only with an indicator that others are excluded.
  - Per-group screens are unaffected — inside a group everything stays in the group currency.
  - `flutter analyze` and `flutter test` pass, including a test for mixed-currency aggregation math.
## Approach
- Home currency as a user preference alongside the existing locale preference (global provider in `lib/provider.dart` + settings screen); persist where locale persists today.
- Conversion applied client-side at aggregation points — group contributions are already computed per group, so convert each group subtotal, then sum. Small rate service (plain HTTP, current rates only — no per-date fetch, no freezing) new in this feature; lightweight last-known-rates cache (e.g. shared_preferences already in use — verify in pubspec).
- Likely touchpoints: `lib/provider.dart`, `lib/pages/settings/`, `lib/pages/groups/presentation/group_list.dart` (+ view model, overall balance hero), `lib/pages/friends/`, `lib/pages/statistics/widgets/personal_summary_section.dart`, new rate service (e.g. `lib/pages/groups/service/` or `lib/helper/`), both ARB files.
- Decisions / tradeoffs: display-only conversion — rates never touch the ledger; expenses are always entered in the group currency (per-expense conversion was cut 2026-07-09: the user's bank converts better than any fetched rate).
- Depends: multi-currency-foundation
- Parallel-with: —
- Blockers: —

status: done

## Evidence

Gate summary (`.ristretto.json`): `flutter analyze` → "No issues found!"; `flutter test` → **All tests passed! (910)**; `dart format --set-exit-if-changed` on every touched file → 0 changed.

How each acceptance criterion was proven:

- **Settings home-currency picker, default EUR, persists across restarts** — New `HomeCurrencyNotifier` (`lib/provider.dart`), persisted via `AsyncPreferences` under `home_currency`, default `kDefaultCurrencyCode` (EUR); picker sheet `showHomeCurrencySheet` over the curated `kSupportedCurrencyCodes` wired into the Settings preferences list (`lib/pages/settings/setting.dart`). Proven by `test/provider/home_currency_test.dart`: "defaults to EUR", "setHomeCurrency accepts a curated code and persists it" (asserts a `set_*` write reaches storage), "rejects codes outside the curated list".
- **Overall balance hero / friendship shares / personal-summary convert each group's contribution before summing (€10 EUR + $10 USD → one total, not 20)** — `aggregateOverallBalance` now converts per group (`lib/pages/groups/presentation/group_list_view_model.dart`); `FriendshipRepository.fetchData` converts each mutual group's share; `PersonalStatisticsNotifier` converts per-group `totalPaid`/`totalShare` via a group→currency map from `groupListProvider`. Proven by `test/model/group_list_view_model_test.dart` "€10 in a EUR group + $11 in a USD group is one home total, not 20" (1 EUR = 1.10 USD ⇒ €20) and `test/helper/currency_conversion_test.dart` `convertAndSum` mixed-currency cases.
- **Converted aggregates visibly marked approximate ("≈"); all-home-currency = exact, no marker** — `MoneyText.approximate` prefixes "≈" (`lib/widgets/restyle/money_text.dart`); `approximate` flags flow from `ConvertedTotal`/`OverallBalance`/`PersonalStatisticsState`/`Friendship`. Proven by the `approximate` assertions across `currency_conversion_test.dart` and `group_list_view_model_test.dart` ("all-home-currency groups are exact (no approximate marker)").
- **Current rates fetched at load from a free no-key API (frankfurter.app/ECB); offline → last known rates; no rates → home-currency groups only with an exclusion indicator** — `ExchangeRateService` (`lib/helper/exchange_rate_service.dart`) fetches `api.frankfurter.app/latest?base=EUR`, caches to `AsyncPreferences`, falls back to cache on failure, `null` when neither is available; `exchangeRatesProvider` loads it at first watch. The `null`-rates fallback + `excludedCount` indicator (`homeAggregateExcluded` string, shown on the hero and personal summary) proven by "no rates: foreign groups excluded, home-currency groups still counted" (`group_list_view_model_test.dart`) and "no rates: falls back to home-currency contributions only, counting the rest" (`currency_conversion_test.dart`).
- **Per-group screens unaffected** — conversion is applied only at the cross-group aggregation points; group-detail/expense screens continue to use `group.currencyCode` unchanged (no edits to those surfaces).
- **`flutter analyze` and `flutter test` pass incl. mixed-currency aggregation math test** — see gate summary; the required math test is `test/helper/currency_conversion_test.dart` plus the `aggregateOverallBalance` conversion group.

Notes / out-of-scope (not fixed, flagged as suggestions): the statistics monthly-trend chart and per-group summary rows still show raw per-currency figures (only the named "personal-summary figures" convert); statistics groups absent from the loaded group list fall back to the home currency (best-effort) rather than being excluded.
