# multi-currency — Design brief (by surface)

> Rewritten 2026-09-11. The previous version of this file described the
> pre-2026-08-11 product model (one currency per group, never converted; a
> cross-group **home currency** marked "≈ approximate"). Both halves of that
> model are gone: expenses are enterable in another currency with a manual
> frozen rate ([multi-currency-expense-rate](multi-currency-expense-rate.md)),
> and the home currency was deleted outright in `730b410` in favour of a
> per-currency breakdown ([multi-currency-group](archived/multi-currency-group.md)).
> That brief also forbade, in bold, the exact expense-editor UI that later
> shipped — which is how four features reached production with no design pass.

**Product model (the one rule everything follows):** a group has exactly one
currency and every balance in it is a real ledger value in that currency. An
expense may be *entered* in another currency; it is converted once, at a rate
the user supplies, and only the converted value reaches the ledger. The
original amount, currency, rate and rate date ride along as **provenance** —
read, never computed with. Across groups nothing is converted at all: totals
are reported per currency.

---

## The currency atom — settled, and used everywhere

This is the decision the old brief listed as an open "cross-cutting" question
and never made; every surface then improvised it differently.

**A currency is named by its ISO code. The app renders no currency symbols at
all.** Symbols cannot do the job: seven supported currencies render as `$`,
four as `kr` and two as `¥`. The two whose symbol *is* unique — CHF and RON —
manage it by being their own code. So the code identifies in every case and the
symbol in none of them, and one form everywhere beats a rule about where a
symbol is safe.

| Where | Form | Helper |
|---|---|---|
| Any amount, anywhere, in either locale | `EUR 10.59`, `JPY 3,000` | `formatMoney` |
| A surface that prints its own code column (hero chips, breakdown rows) | `10.59` | `MoneyText(showSymbol: false)` |
| A picker row | code + English name — `CHF · Swiss Franc` | `Currency.name` |
| A selected-value row ("Entered in", group currency) | `CHF` | `Currency.code` |

Two consequences worth stating, because both are places the old design let the
locale decide something it should not have:

- **Placement never flips.** Symbol placement is locale-dependent (`$1,234.56`
  in `en`, `1.234,56 $` in `de`); the code always leads, in every locale. Only
  the separators follow the locale. The reading order is one thing the user
  never has to relearn.
- **`Currency.symbol` is reference data and is never rendered.** It is kept on
  the registry because it is a true fact about the currency, not because
  anything displays it.

## 1. Home hero — reports per currency, never "overall"

- **Single currency:** unchanged. "Overall, you're owed €10.59" over the
  owed/owe stat pair. With one currency "overall" is exactly true.
- **Several currencies:** the lead **names the currency it is reporting**
  ("You're owed in EUR") and the owed/owe pair is **replaced** by one chip per
  remaining currency — code over bare amount, tinted by direction.
- **Constraint:** the hero must never state a cross-currency total, because
  none exists. The old hero claimed one: `overall` is computed in the primary
  currency only, so a user owed €10.59 while owing $4.00 and CHF2.14 read
  "Overall, you're owed €10.59" with "You owe €0.00" beside it.
- **Constraint:** the remaining currencies are always visible. They were behind
  a "+2 more currencies" disclosure; a debt you have to tap to discover is a
  debt you forget. The disclosure widget survives only on statistics, where the
  list is genuinely unbounded and it doubles as the trend chart's selector.

## 2. Group ledger — a converted row says so

- **What it shows:** the group-currency ledger value stays the headline (every
  balance on screen derives from it), with the entered amount beneath it,
  code-qualified and muted: `€4.24` over `CHF 4.50`.
- **Constraint:** never show only the ledger value. Abroad, *every* row is
  converted; without the entered amount the list is unrecognisable against the
  evening the user actually remembers.
- **States:** group-currency row (nothing added) · converted row (two lines).

## 3. Expense read view — provenance is a block, not a footnote

- **What it shows:** a labelled two-row block under the amount —
  `Entered as · CHF 4.50` and `Rate · 1 CHF = 0.9432 EUR · 11.09.2026`.
- **Constraint:** the rate always carries its **direction**. A bare `0.9432`
  can be read either way round, and the reader cannot tell which without doing
  the arithmetic.
- **Constraint:** the rate is a ratio, not money — it keeps its own precision
  and is never formatted at a currency's decimal digits (`EUR 0.94` would be a
  different, wrong number).
- **Constraint:** read-only. Nothing here is ever recomputed.

## 4. Expense editor — the rate field reads as a sentence

- **What it shows:** "Entered in" picker (`Currency.code`), then, only
  for a foreign currency, the rate inside a card like every other control on
  the screen: `Rate`, `1 CHF = [ 0.9432 ] EUR`, the live converted preview, and
  the clear action.
- **Constraint:** no `?` placeholder in a label. The old label read
  "Rate: 1 CHF = ? EUR" and kept the `?` after a rate had been typed.
- **Constraint:** actions name their object — "Clear saved rate", not "Reset",
  which sits beside the converted preview and reads as though it would reset
  the amount.
- **Constraint:** no implicit rate, ever. An empty rate blocks the save with a
  visible reason; there is no 1:1 fallback.

## 5. Currency picker — one sheet, searchable

- **What it shows:** a search field over every supported currency, each row a
  fixed-width code lane and its English name — `CHF · Swiss Franc`. A check
  marks the current choice and nothing marks the rest.
- **Why two lanes:** there are two ways to know a currency and the list is 31
  long. Codes are all three characters, so the fixed lane forms a column an eye
  can run down; someone who only knows "Swiss Franc" reads the other lane, and
  the search matches either.
- **Why not the symbol:** the old row read `EUR · €`. With symbols gone from
  every amount, showing one here teaches a glyph the user will never see again.
  The name is the useful second field.
- **Constraints:** the search matches code or name on any substring, case
  insensitively; an empty query restores the full list; a query matching
  nothing says so and names the query. The clear affordance exists only once
  there is something to clear.
- **Names are not localized** — they are proper nouns of the ISO register, and
  they are what people type into the search.

## 6. Group create / edit

- Currency picker via the shared sheet; the relabel warning stays as written.
- The picker **locks** once any expense in the group carries a different
  original currency (`canChangeGroupCurrency`).

## 7. Friend sheet — the same rule as the hero

A friendship held in one currency keeps its net inline beside the name. Held in
several, the inline figure **goes away** and every currency gets a chip.

`shareAmount` is the primary currency's net, so "JPY 3,000" beside Sam's name
read as the state of the friendship when the truth was that you are owed in JPY
and owe in EUR — the identical defect the home hero had. Both surfaces now
share one widget, `CurrencyChips`, so the treatment cannot drift apart again.

The disclosure went with it. A friendship spans only the groups two people
share, so its currency list is strictly shorter than the hero's — there was
never anything here worth collapsing. The primary still drives the pay-back
flow (which methods appear, and the amount the confirmation names); it simply
no longer stands in for the whole balance visually.

## 7b. Friend list row — the balance stacks

Label over amount, right-aligned, with the other-currency marker on a third
line when there is one. Laid out along the row — label, amount and marker side
by side — the balance took enough width to ellipsise the friend's handle
(`jaggkovsky#92…`): the identity was losing room to the money. A stacked column
is only as wide as its widest line.

This is also what the group card already does, so the two lists read the same
way.

A multi-currency row is therefore one line taller than a single-currency one.
That is information, not inconsistency — the row is carrying more.

The row keeps the primary-plus-count form rather than the sheet's chips: it is
a dense list row, and a count marker is an honest "there is more here" without
claiming the figure beside it is the whole story.

## 8. Statistics

Per-currency, same rule: no conversion, no approximate marker, each figure
exact in its own currency. Keeps the collapsing disclosure — its list is
genuinely unbounded, and there the disclosure doubles as the currency selector
for the trend chart.

## Sheets and lists — two layout rules

- **A bottom sheet's surface runs to the screen edge.** `SheetScaffold` puts
  its `SafeArea` INSIDE the `Material`, so the content clears the gesture bar
  while the sheet's own colour reaches the bottom. Around the `Material` — as
  it was — the bottom inset became a visible gap with the scrim showing
  through underneath.
- **A list pads for what is actually there.** The shell is a plain `Scaffold`
  with a `bottomNavigationBar` and no `extendBody`, so a list already stops
  above the nav and needs no clearance for it. Only a floating element earns
  extra bottom padding, and only while it exists.

---

## Not done

- Receipt scanning is currency-blind: the parse happens server-side, so what a
  CHF or GBP receipt yields is untested. Pre-existing, not introduced here, but
  it will read as a conversion bug to anyone scanning a receipt abroad. Note
  the receipt PARSER still strips `€` and `$` from OCR text — that is input,
  not display, and is unaffected by the no-symbols rule.
