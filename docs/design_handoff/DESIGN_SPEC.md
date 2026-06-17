# Deun Redesign — Design Spec (visual reference)

The exact visual/behavioral reference for the redesign. Pairs with `README.md` (codebase map + rules) and
`ROADMAP.md` (tasks). Source of truth for pixels/copy: the interactive prototype `Deun Redesign v2.dc.html`.

> **Implementation note:** values below are the *target design*. In the Flutter app, express them through
> `ThemeData`/`ColorScheme` + theme extensions (see README "Theme & tokens"), not hard-coded hex in widgets,
> so light **and** dark both work. The prototype is light-only by necessity.

---

## Design System

### Typography
| Role | Family | Notes |
|---|---|---|
| Display / headings / amounts | **Bricolage Grotesque** | weights 500–800, `letter-spacing:-0.02em`; screen titles, big amounts, group names |
| Body / UI / labels | **Hanken Grotesk** | weights 400–800; default UI font |
| Icons | Material Symbols (prototype) → **Material Icons** in Flutter | every glyph maps to a Flutter `Icons.*` |
| All numerals | (either) | always tabular figures for amounts |

Type scale (px): hero amount 58 / 46 / 42 / 40, screen title 30 / 27–28, section header 18, card title 15–19,
body 13–15, caption 11–12.5, micro label 10–10.5, tab-bar label 10.

### Color tokens
| Token | Hex | Use |
|---|---|---|
| **Primary / accent** | `#5750E6` | brand indigo: CTAs, active states, FAB, links, "you" avatar |
| Primary tint | `#ECEBFC` | accent surfaces, selected category, claimed-by-you cards (`#F3F2FD` card / `#D9D5FA` border) |
| Ink (text / dark cards) | `#16181A` | primary text, dark hero cards, sheet headers |
| App background | `#F4F3EF` | screen background |
| Bars / footers / sheets | `#FBFAF7` | tab bar, sticky footers, sheet surfaces |
| Card surface | `#FFFFFF` | list cards, inputs |
| Field fills | `#F4F3EF` / `#F1EFE9` / `#EAE8E1` / `#F0EEE8` | inset fields, segmented track, progress track |
| Text secondary | `#A39F94` | captions, secondary labels |
| Text tertiary / icon | `#8C8980` / `#56524A` / `#9A968C` | muted labels, list icons |
| Disabled / placeholder | `#B6B2A8` / `#C2BEB4` / `#C9C5BB` | placeholders, chevrons |
| Hairlines | `rgba(20,18,12,0.05–0.08)` / `#E4E1D8` / `#D5D8D4` | dividers, input borders, unchecked radios |
| **Success** (owed / positive) | `#1A8F5E` | "you're owed", lent, settled; `#4ED99B` on dark cards |
| **Danger** (owe / negative) | `#D85A47` | "you owe", delete, over-allocated; `#F2937F` on dark cards |
| **Warning** (amber) | `#C98A2E` / `#E3A02E` | unclaimed callouts, favorite star; `#F2C97F` on dark |
| Payback green chip | bg `#EAF6EF`/`#D6EEDF`, text `#2F7A55`/`#1A8F5E`/`#5FA882` | settle/payment rows in ledger |

**Group color palette** (group picker — feeds `Group.colorValue`). Color + light tint:
`#5750E6`/`#ECEBFC` · `#2F73D9`/`#E4EEFB` · `#E0853D`(`#E0735A`)/`#FBEEDD`(`#FBEAE5`) · `#D45A8A`/`#FBE7F0` ·
`#B85C9E`/`#F6E8F1`.

**Member avatar colors** — stable per person (You `#5750E6`, Sam `#2F73D9`, Priya `#E0735A`, Jonas `#E3A02E`,
Lena `#B85C9E`, Theo `#4C6FB5`, Noah `#3F9E84`, Aria `#C76A4E`, Liam `#8268C8`, Mara `#C99A2E`; guests
neutral `#9A968C`). White initials. Derive deterministically from email/id in code.

### Dark mode palette (required)
The prototype renders light only; these are the **target dark tones** — land them in the `Brightness.dark`
block of `theme_builder.dart`. Keep the **same accent and semantic hues**, only swap surfaces/text; semantic
colors use their lighter on-dark variants so they stay legible.

| Token | Light | **Dark** | Notes |
|---|---|---|---|
| App background | `#F4F3EF` | `#121311` | warm near-black, not pure `#000` |
| Bars / footers / sheets | `#FBFAF7` | `#1A1B19` | tab bar, sticky footers, sheet surface |
| Card surface | `#FFFFFF` | `#1F211E` | list cards, inputs |
| Card surface (raised/2nd) | `#FFFFFF` | `#262824` | nested cards, chips on cards |
| Dark hero card | `#16181A` | `#262824` | hero becomes a *lighter-than-bg* card in dark |
| Field fills | `#F1EFE9` / `#EAE8E1` | `#262824` / `#2E302B` | inset fields, segmented track |
| Primary text | `#16181A` | `#ECEBE6` | on bg/cards |
| Text secondary | `#A39F94` | `#9A968C` | captions |
| Text tertiary / icon | `#8C8980` / `#56524A` | `#7E7A72` / `#B7B2A8` | muted labels, list icons |
| Disabled / placeholder | `#B6B2A8` | `#5E5B54` | placeholders, chevrons |
| Hairlines | `rgba(20,18,12,.06)` | `rgba(255,255,255,.08)` | dividers, borders |
| **Accent** | `#5750E6` | `#7A74F0` | slightly lifted indigo for contrast on dark |
| Accent tint surface | `#ECEBFC` | `#2A2950` | selected category, claimed-by-you card |
| **Success** | `#1A8F5E` | `#4ED99B` | use the on-dark variant everywhere in dark |
| **Danger** | `#D85A47` | `#F2937F` | on-dark variant |
| **Warning** | `#C98A2E` | `#F2C97F` | on-dark variant |

Group and member avatar colors stay the same in both themes (their tints darken via the surface mapping).
These are a tuned starting point — verify contrast (WCAG AA on body text) and adjust within ±1 step if needed.

The redesigned Settings → **Appearance** row is a working **System / Light / Dark** picker (sheet with
`brightness_auto` / `light_mode` / `dark_mode` options); wire it to the app's `themeMode`
(`ThemeMode.system/light/dark`) in `navigation.dart`. In the HTML prototype, picking **Dark** flips the screen
live so you can preview the feel — note that the prototype uses a luminance-invert as a stand-in; the **exact
dark tones to implement are the table above**, not the inverted preview.

### Radii / Shadows / Spacing / Motion
- **Radii:** big/hero cards 22–26, list cards 16–20, inputs 14–16, sheets `28` top (matches current theme),
  pills/avatars/toggles `999`/`50%`, small chips 11–14.
- **Shadows:** card `0 2px 4px rgba(20,18,12,.04)`; hover lift `0 10px 22px -10px rgba(20,18,12,.18)`;
  dark hero `0 18px 30px -18px rgba(20,18,12,.5)`; primary button/FAB `0 12–14px 22–26px rgba(87,80,230,.5)`.
- **Spacing:** screen H-padding 20 (headers 14–26); 8–12 between cards; 14–24 between sections; sticky footer
  `14/20/20`; tab bar 78 tall; scroll areas pad-bottom 110–120 under FABs/footers.
- **Motion:** sheet rise `translateY(101%)→0` 0.28s `cubic-bezier(.22,1,.36,1)`; scrim fade 0.2s; scan-line
  sweep 2.4s loop; presence dot pulse (scale+opacity) 1.6s loop.

---

## App shell
Three home tabs in a bottom `NavigationBar` (already built in `navigation.dart`): **Groups** (`receipt_long`),
**Friends** (`group`, badge = pending requests), **Settings** (`settings`). Non-home screens are full pages
with back-arrow app bars; pickers/confirms are bottom sheets over a scrim. Active accent `#5750E6`, inactive `#ADA99F`.

## Screens / Views
Open `Deun Redesign v2.dc.html` to interact. Each screen's existing Flutter file is in README's screen→code map.

1. **Login / Sign-up** — app icon (`call_split`), title ("Welcome back"/"Create your account"), social buttons
   (Apple dark / Google / GitHub), divider, email+password (+name on signup), forgot-password (login), primary
   submit, mode-switch link. Social/signup → onboarding; login → home.
2. **Password recovery** — back, title, instructions, email, "Send reset link".
3. **Onboarding username** — `alternate_email` tile, username field with leading `@` + fixed `#code`
   discriminator + live "@user#code" preview, display-name field, "Get started". Username sanitized `[a-zA-Z0-9_]`.
4. **Home · Groups** — greeting + avatar; **dark overall-balance hero** ("you're owed €X" + owed/owe stat
   chips, from `Group` summaries aggregated); "Your groups" + New; **group cards** (tinted icon, name, favorite
   star toggle, chevron; footer = member avatar stack + balance lead/amount, green owed/red owe/gray settled).
   Sort: fav-unsettled → fav-settled → unsettled → settled.
5. **Home · Friends** — title + QR + person-add; **incoming requests** (accept/decline); **outgoing** (cancel);
   **all friends** (avatar, name, balance label → friend sheet). Tab badge = incoming count.
6. **Home · Settings** — sign-out; dark profile card (name, `@user#code`, email); **profile form** (first/last,
   username copy, PayPal.me, IBAN, Language → sheet, Update); list (Your statistics, Notifications toggle,
   Appearance, Privacy policy, Contact); **Delete account** (confirm sheet); version footer.
7. **Group detail** — back/name/edit app bar; **color hero** (balance lead+amount, member stack, "Settle up" →
   payment); quick actions **Statistics** + **Invite**; **ledger grouped by day** with 3 row types:
   • *quick expense* (icon, title, "{payer} paid · you lent/owe €X", amount → read detail);
   • *itemized expense* (accent left-bar + "Tap to claim" pill until you've claimed; claimer avatars + "€X
   unclaimed/all claimed"; after claiming → green "You claimed €X"; → Tap-to-Claim);
   • *payback* (green inset "Sam paid you €40 · PAYMENT"). Empty state. Floating **Scan** + **Add expense** FABs.
8. **Expense editor** — top segmented **Quick split / Itemized**.
   *Quick:* category tile (→ category sheet), big amount (→ keypad sheet), description, paid-by + when rows,
   **Split** w/ 4-way segmented **Equal/Shares/%/Exact**, allocation bar, remaining indicator (green/amber/red),
   per-member rows (include checkbox, avatar, stepper for non-equal, amount). Maps to existing `SplitMode` +
   `expenseEntryShares`.
   *Itemized:* total-from-N-items + Scan; description; paid-by/when; **Items** list (editable name, unit price,
   qty stepper, line total, delete), "Add item by hand", info callout. CTA "Add expense"/"Save changes"/(itemized)
   "Add & share for claiming". **Dirty-guard**: Back while dirty → Discard sheet.
9. **Tap to Claim** *(NEW)* — merchant header + live-presence pulse dot + edit-items; **persona "Preview as"
   switcher** (prototype affordance / real per-user view); **dark summary card** (your share, claimed/total
   progress, unclaimed, per-member totals); **item cards** with per-unit **chips** (claimed = avatar(s)+name /
   "split · €X"; open = dashed "take one"); **"Split one"** inline member picker (per-unit cost); unclaimed
   callout + Nudge; sticky "Confirm — I had €X" → success sheet. See README for the data-model decision.
10. **Settle up** — color hero (overall); **You pay** (Pay → method detail) / **Owes you** (Remind); detail =
    avatar + amount + payment-method cards (PayPal/Bank-IBAN/Cash — only methods the payee has, from
    `GroupSharesSummary.paypalMe/iban`), sticky "Pay €X"/"Mark settled" → Settled.
11. **Expense detail (read)** — summary card (icon, title, cat·date, total, payer, your net lent/owe), itemized
    "Review & claim" banner, per-member breakdown + tags. Delete + Edit.
12. **New / Edit group** — name + color swatch row (retints icon), member toggles + add-guest, tracking-mode
    radio (Simplified ↔ `simplifiedExpenses`), sticky Create/Save.
13. **Group statistics** — range (3M/6M/12M/All) + period stepper, color summary (total/Δ/avg/count/biggest),
    monthly trend bars (→ month sheet), members paid-vs-fair bars, category bars (→ category sheet).
14. **Personal statistics** — dark paid/share card, monthly spend bars, by-group list.
15. **Add friend** (search `user#code`, results, contacts, Add/Requested) & **QR** (My-code QR + Copy/Share /
    Scan viewfinder).

**Sheets:** keypad, receipt scan, category (icon grid — use `ExpenseCategory` enum: `getIcon`/`getColor`/
`getDisplayName`), paid-by, date, friend detail, invite, language, delete-confirm, stat month, stat category,
discard-confirm.

## Interactions & Behavior
- **Split math** (quick): Equal = amount/included; Shares = amount·parts/Σparts; %·amount/100; Exact = entered.
  Allocation bar + remaining indicator live; steppers ±1× / ±5% / ±€0.50. Maps to `SplitMode` + entry shares.
- **Itemized claim math**: a unit's cost to a member = `unit / claim.members.length` summed over claims
  including them; member total = Σ over items; claimed = Σ`claims.length·unit`; unclaimed = total−claimed
  (payer covers unclaimed). Mirrors `Expense.groupMemberShareStatistic`.
- **Favorites** re-sort groups instantly; star tap must not open the card.
- **Friend requests** accept/decline/cancel update lists + tab badge live.
- **Keypad** limits 2 decimals / 7 digits / single point.
- **Edge states**: empty ledger, settled groups (gray, no amount), fully-claimed vs unclaimed callouts,
  over/under-allocated split warnings.

## State & Data (prototype model → app model)
The prototype's in-memory state mirrors the app's real models:
- `Member` → Supabase `user` / `group_member` (`email, displayName, username, usernameCode, isGuest`,
  + `paypalMe`, `iban`).
- `Group` → `group_model.dart` (`id, name, colorValue, simplifiedExpenses, groupMembers,
  groupSharesSummary, totalShareAmount, isFavorite`). **Balances/settlement already computed here** — the
  prototype's hard-coded totals just bind to these.
- `Expense` → `expense_model.dart` (`expenseEntries`, `groupMemberShareStatistic`, `category`, `paidBy`).
- `ExpenseEntry` → `expense_entry_model.dart` (`name, amount, quantity, splitMode, unitPrice`,
  `expenseEntryShares[{email, percentage, fixedAmount, parts, isLocked}]`). This is the itemized/claim substrate.
- `Payback` → `is_paid_back_row` expense rows.

## Assets
- **Fonts:** Bricolage Grotesque + Hanken Grotesk (if aesthetic adopted) via `google_fonts` or bundled.
- **Icons:** all map to Flutter `Icons.*` (categories already do, via `ExpenseCategory.getIcon`).
- **No raster assets** — QR generated, avatars are initials, camera/receipt previews are styled placeholders.
- Use official Apple/Google/GitHub marks for social login in production.
