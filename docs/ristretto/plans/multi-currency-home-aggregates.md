# multi-currency-home-aggregates — Home currency for cross-group balances & statistics

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08)
- Flight: multi-currency
- Goal: The user picks a home currency; every total that spans groups (overall balance hero, friendship balances, statistics) converts mixed-currency amounts into it instead of summing raw numbers.
- Acceptance:
  - Settings has a home-currency picker (same curated list as group currencies); default EUR; choice persists across app restarts.
  - The overall balance hero on the group list, friendship shared amounts, and the statistics/personal-summary figures convert each group's contribution from its group currency into the home currency before summing; a user with a €10 balance in a EUR group and a $10 balance in a USD group sees one home-currency total, not 20.
  - Converted aggregates are visibly marked as approximate (e.g. "≈" prefix); a user whose groups are all in the home currency sees exact values with no marker.
  - Cross-group conversion uses current rates fetched at load via the rate service from multi-currency-conversion; when rates are unavailable (offline), the last known rates are used, and with no rates at all the aggregate falls back to home-currency groups only with an indicator that others are excluded.
  - Per-group screens are unaffected — inside a group everything stays in the group currency.
  - `flutter analyze` and `flutter test` pass, including a test for mixed-currency aggregation math.
## Approach
- Home currency as a user preference alongside the existing locale preference (global provider in `lib/provider.dart` + settings screen); persist where locale persists today.
- Conversion applied client-side at aggregation points — group contributions are already computed per group, so convert each group subtotal, then sum; reuse the rate service, add a lightweight last-known-rates cache (e.g. shared_preferences already in use — verify in pubspec).
- Likely touchpoints: `lib/provider.dart`, `lib/pages/settings/`, `lib/pages/groups/presentation/group_list.dart` (+ view model, overall balance hero), `lib/pages/friends/`, `lib/pages/statistics/widgets/personal_summary_section.dart`, both ARB files.
- Decisions / tradeoffs: current-rate (approximate) conversion for display-only aggregates — unlike expenses, these are not frozen because they are informational, not ledger values.
- Depends: multi-currency-conversion
- Parallel-with: —
- Blockers: —

status: planned
