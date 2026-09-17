# expense-card-fee — Design brief

> Written 2026-09-17, out of a live bug walk: a 5 170 Ft receipt in a EUR group
> settled at €14.17 by ECB reference while the card statement said €14.32. The
> gap is the bank's foreign-transaction markup, and the app had nowhere to put
> it. Canvas: [Deun — Rate & Card Fee](https://claude.ai/artifact/Qi8bwY7CYTYBw6r3vhdaot).

**The rule everything follows:** a card fee is a fact about the user's *payment
card*, not about the expense. It does not vary by expense, group or currency
pair, and the group never agrees on it — they only agree on the final amount.
So it is stored once, per device, and it modifies **the rate Deun suggests**.
It never becomes a column on `expense`, and it never touches a number the user
typed.

This brief covers two things that arrived together: where the fee lives, and
the density fix it forces. The second is not incidental — the currency/rate
block was already the busiest part of the editor, and bolting a second number
field onto it was not available.

---

## Why the fee is not an expense field

The obvious design — `fee_percent` on `expense`, threaded through
`save_expense_all`, a hand-applied migration — was rejected, and the reason is
worth recording because it looks like the more rigorous option.

`conversion_rate` does not mean "the ECB reference rate". It has never meant
that: the field is free text and a user may type any number into it. It means
**the rate this expense used**. A fee folded into that number is therefore not
a loss of provenance — it is the column doing its job.

What the stored-column version buys is the read view being able to print
"0.002741 + 1.4%" instead of "0.0027789". What it costs is a schema change on
an instance only Jakob can reach ([manual-checks.md](../manual-checks.md)), plus
the RPC re-stated, plus the model and repository threading. The trade is not
close.

The one real hazard a column would have removed is **double-application**: if
the stored rate already carries the fee, reopening the expense and re-saving
must not apply it again. That hazard is removed instead by the invariant below,
which costs nothing.

## The invariant: the fee modifies a *suggestion*, never a number

The editor already distinguishes where a rate came from — `_RateOrigin` in
`expense_detail.dart`:

| Origin | Meaning | Fee applies? |
|---|---|---|
| `prefilled` | Deun fetched it from `exchange-rate` | **Yes** — multiplied in before it reaches the field |
| `user` | The user typed it, *or* a saved expense froze it, *or* it came from the sticky rate | **No** |
| `none` | No rate in the field | n/a — nothing to modify |

Three consequences, all of them the point:

- **Reopening a saved expense cannot double-apply.** A loaded rate is
  `_RateOrigin.user`, so the fee path never runs on it.
- **A typed rate is never second-guessed.** If the user enters the rate their
  statement actually shows, the app must not "improve" it.
- **A sticky rate is a typed rate.** It is only ever remembered from a rate the
  user supplied, so it inherits the same immunity.

The fee is applied once, at the moment a fetched quote lands in the field, and
from then on it is simply part of the rate.

## 1. The conversion block — two cards become one

Today the foreign-currency state stacks two cards and three tap targets before
the description field is reached:

| Today | Proposed |
|---|---|
| Card: `Entered in · HUF ⌄` | Same row, now the top half of one card |
| Card: rate label, open `TextField`, helper line, hairline, `= €14.17`, `Clear saved rate` | One row: the converted amount, plus provenance chips, plus a chevron |
| 3 tap targets, ~226 px | 2 tap targets, ~145 px |

The second row reads as a result, not a form:

```
Entered in                          HUF ⌄
─────────────────────────────────────────
€14.37
[ECB 16 Sep]  [+1.4% card fee]           ›
```

- The amount is Bricolage 26 / w700, tabular figures — it is the number the
  ledger will hold, so it gets display weight.
- The chips are the whole provenance story at a glance. Neutral `#F1EFE9` for
  the source, accent tint `#ECEBFC` / `#4A43CC` for the fee, so the fee is
  legible as *yours* rather than as data from the rate source.
- **The fee is a chip, never a field.** It is a per-user constant; giving it an
  input on the expense screen would imply it is per-expense, which is exactly
  the wrong model.

The rate field and `Clear saved rate` leave the main screen entirely.

## 2. The conversion sheet — where the rate now lives

Standard sheet shell ([COMPONENTS.md](../../design_handoff/COMPONENTS.md) §3):
`#FBFAF7`, top radius 30, 38×4 `#D6D2C7` handle, content padding `8 / 20 / 26`,
title Bricolage 24 / w700.

Contents, in order:

1. **The conversion, stated** — `5 170 Ft → €14.37` on a white card. The entry
   amount is secondary weight, the ledger amount primary.
2. **Rate** — the inset field (`#F1EFE9`, radius 15) that used to sit on the
   main screen, still reading as a sentence: `1 HUF = [0.0027789] EUR`.
3. **The source line** — "ECB reference for 16 Sep 2026 was 0.0027405." This is
   what makes the fee *checkable*: both numbers are on screen, and the user can
   see the 1.4% between them.
4. **Card fee** — a row showing the current value, tapping through to change
   it. Writes the same preference Settings writes.
5. **Honesty copy** — "Added to rates Deun looks up, never to a rate you type
   yourself. Your bank converts at its own rate, so treat this as close, not
   exact."
6. `Clear saved rate`, unchanged in behaviour.
7. `Done`.

Point 5 is load-bearing. The observed markup on the walk was **1.06%**, not the
1.4% the card advertises, because card networks convert at their own wholesale
rate and then add the fee — ECB is not their base. The feature must not imply
it reconciles a statement. It gets you close and it shows its working.

## 3. Settings — one row, one number

A `Foreign transaction fee` row in the Preferences list, between
`Your statistics` and `Notifications`: title, the subtitle "Added to exchange
rates Deun looks up", the value right-aligned, chevron. This is where a
per-user constant belongs, and it is where a user who has never opened a
foreign expense will still find it.

Discoverability is carried by the sheet, not by Settings — nobody goes looking
in Settings for a thing they have not needed yet.

## 4. States

| State | Amount | Chips |
|---|---|---|
| Fee set, rate fetched | `€14.37` | `ECB 16 Sep` · `+1.4% card fee` |
| No fee set | `€14.17` | `ECB 16 Sep` |
| User typed the rate | `€14.32` | `Your rate` |
| No rate for that date | `Rate needed` (`#C2BEB4`) | `No ECB rate for 16 Sep` (`#FBEEDD` / `#9A6A17`) |

**No fee set is the current behaviour, untouched.** No extra chip, no "add a
fee" prompt, no nag. A user who never sets one sees exactly what they see
today.

The no-rate state keeps today's semantics: the save stays blocked
(`expenseRateRequired`), and the row is the way into the sheet to type one.

## 5. Storage

A device preference, the same shape as `StickyRateNotifier` in `provider.dart`
— `AsyncPreferences`, one key, hydrated behind a `Future`, synchronous read
after `hydrated`. One number, not keyed by group or currency, because the card
is the card.

It is **not** user-scoped state in the Supabase sense: it survives a user
switch on the same device, like `ThemeModeNotifier` and
`NotificationsEnabledNotifier`, and so is excluded from
`invalidateUserScopedProviders` for the same reason they are.

## 6. Copy

| Key | English |
|---|---|
| Settings row | Foreign transaction fee |
| Settings subtitle | Added to exchange rates Deun looks up |
| Sheet title | Conversion |
| Sheet fee row | Card fee |
| Source line | ECB reference for {date} was {rate}. |
| Fee helper | Added to rates Deun looks up, never to a rate you type yourself. Your bank converts at its own rate, so treat this as close, not exact. |
| Fee chip | +{percent}% card fee |
| Source chip | ECB {date} |
| Typed-rate chip | Your rate |
| No-rate chip | No ECB rate for {date} |

German needed for all of them.

## Not done

Deliberately out of scope, each its own feature:

- **The scan fetches a wrong date.** A Hungarian receipt printing `2026.09.16.`
  resolved to 2016-09-26, which fetched a 2016 rate (~307 HUF/EUR against
  today's ~365) and settled the expense 19% high. The parse happens in the
  `parse-receipt` Edge Function, which is **not in this repo**.
- **`2 336` read as `336`.** Space-separated thousands, the actual cause of the
  original "it says 3 euros" report. Same function.
- **The scan's detected total is discarded** whenever line items are found
  (`expense_detail.dart`, `_scanReceipt`), so an incomplete item list silently
  becomes the expense with nothing reconciling it against the total the
  scanner itself displayed.
- **The scan never detects currency.** `ReceiptScanResult` has no currency
  field; amounts land in whatever currency is selected.
- **`switchBackAmountTexts` is asymmetric.** Picking the group's currency
  re-converts every amount field at the frozen rate, while picking a foreign
  currency only relabels — so `EUR → HUF → EUR` divides the entered amounts by
  the rate, destructively and with no undo.
- **`ReceiptParser` is dead code.** Nothing in `lib/` calls it; the scan path
  runs through `GeminiReceiptParser`. It still carries five test files.
- **`Currency.huf` declares `decimalDigits: 2`**, so forints render as
  `5000.00`. Cosmetic.
