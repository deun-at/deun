# multi-currency — Design brief (by surface)

Handoff doc for visual design against the running app mockup. Engineering specs live in two
phase-ordered plans ([foundation](multi-currency-foundation.md) →
[home-aggregates](multi-currency-home-aggregates.md)); this file re-pivots them by **screen/surface**
so each surface is designed once. Apply changes to the existing screens — don't rebuild.

**Product model (the one rule everything follows):** a group has exactly one currency, and every
amount in it is a real ledger value in that currency. Users always enter the group-currency amount —
their bank already converted it (fees, spread and all), better than any fetched rate could. The app
**never converts ledger values**. The only conversion anywhere is display-only: cross-group totals
shown in the user's home currency, marked approximate.

Phase tags: **[P1]** foundation · **[P2]** home-aggregates.

---

## 1. Currency picker — shared control  [P1 group, P2 home]
One picker, two homes: group create/edit currency (P1) and settings home currency (P2).

- **States:** default (EUR preselected) · open/expanded · searching/filtering.
- **Open questions:**
  - Searchable list, flag grid, or short curated favourites + "more"? Curated list is EUR/USD/GBP/CHF
    + other major ISO codes `intl` can format — dozens, not hundreds.
  - Show flag, ISO code, symbol, full name — which combination? (e.g. "🇺🇸 USD · $ · US Dollar")
  - Inline in the form vs. bottom-sheet vs. full page?
- **Constraints:** curated ISO 4217 list only; identical picker in both places.

## 2. Group create / edit  [P1]
- **What changes:** add the currency picker (surface 1). Edit mode adds a **relabel warning**.
- **States:** create (default EUR) · edit same currency · edit changing currency (warning visible).
- **Open questions:** how loud is the warning? Inline helper text vs. confirm dialog on change.
  Copy for "this relabels existing amounts, it does **not** convert their value."
- **Constraints:** changing currency **relabels only, never converts**. The warning must say so.

## 3. Group list + balance hero  [P1 symbols, P2 home total]
- **What changes:** every row formats in its **own** group currency — a USD group and a EUR group sit
  side by side with different symbols (P1). The overall balance **hero** sums across groups → one
  **home-currency** total (P2).
- **States:** all groups in home currency (exact, no marker) · mixed currencies (≈ approximate) ·
  rates unavailable/offline (fallback: home-currency groups only + "others excluded" indicator).
- **Open questions:**
  - How to mark the hero total approximate — "≈" prefix, footnote, tooltip, muted style?
  - The "some groups excluded, rates unavailable" indicator: badge, subtext, icon?
- **Constraints:** per-group rows always exact in their own currency; only the cross-group hero is
  approximate. Symbol placement is locale-aware ("$1,234.56" vs "1.234,56 €").

## 4. Expense editor & read view  [P1 — formatting only]
- **What changes:** amounts, totals and share previews format with the group's currency symbol
  instead of hardcoded €. **No currency picker here, no rate field, no dual amounts** — an expense is
  always in its group's currency, per the product model above.
- **States:** none new — same screens, correct symbol.
- **Constraints:** if a design iteration sprouts per-expense currency UI, that's out of scope — cut.

## 5. Friends  [P1 symbols, P2 home total]
- **What changes:** shared amounts format per group currency (P1); cross-group friendship totals
  convert to home currency (P2, same ≈ treatment as the hero).
- **States / questions / constraints:** mirror surface 3 — reuse the same approximate marker so the
  app reads as one system.

## 6. Statistics / personal summary  [P1 symbols, P2 home total]
- **What changes:** personal-summary and statistics figures convert mixed-currency contributions into
  home currency before summing.
- **Open questions:** where does an ≈ marker go on a stat tile or chart without clutter?
- **Constraints:** informational, current rates, display-only.

## 7. Settings — home currency  [P2]
- **What changes:** a home-currency picker (surface 1), persisted across restarts, alongside the
  existing locale/language setting.
- **Open questions:** grouping/placement next to language; one-line explainer of what "home currency"
  affects (hero, friends, statistics)?
- **Constraints:** same curated list as group currencies; default EUR.

---

## Cross-cutting design decisions (settle these first — they propagate everywhere)
1. **Approximate marker** ("≈" style/placement) — used on hero, friends, statistics. One treatment.
2. **Currency display atom** — flag/symbol/code combination, reused in picker, rows, group headers.
3. **Amount + symbol formatting** — locale-aware placement; today this is `MoneyText` /
   `widgets/restyle/`. New visuals stay consistent with that existing language.
4. **Exact vs approximate signalling** — always clear when a number is a real ledger value
   (everything inside a group) vs a display-only estimate (cross-group aggregates).
