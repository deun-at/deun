# Handoff: Deun Redesign — Flutter app (`deun-at/deun`)

## Overview
This is a **visual + UX redesign of the existing Deun Flutter app** — not a new build. The prototype
(`Deun Redesign v2.dc.html`) shows the target look and the flows; the app already implements almost all of
this functionality. The job is mostly **restyling existing screens** to the prototype's design language,
plus one genuinely new feature (**Tap to Claim**).

Read this together with `ROADMAP.md` (the task breakdown) and `DESIGN_SPEC.md` (the visual reference:
tokens, per-screen layouts, copy). This file maps the prototype onto your actual code and states the rules.

## ⚠️ Corrections to a generic handoff (read first)
The prototype is a self-contained mock; several things it *appears* to introduce **already exist** in the
codebase. Do not rebuild them:
- **Balances & settlement are real.** `Group` in `lib/pages/groups/data/group_model.dart` computes
  `totalShareAmount`, `groupSharesSummary`, and a **minimal-transaction simplified settlement**
  (`calculateGroupSharesSummarySimplified`) from a Supabase `group_shares_summary` view. The prototype's
  hard-coded "€180.30 / you're owed" numbers just need wiring to these existing fields. **No "balance engine" to build.**
- **Receipt OCR is real.** `lib/pages/expenses/service/gemini_receipt_parser.dart` + `receipt_parser.dart`
  + `receipt_scanner_sheet.dart` already parse receipts into items. The "Scan" UI is a restyle, not new tech.
- **Itemized expenses are real.** An `Expense` already holds `expenseEntries: Map<String, ExpenseEntry>`,
  each entry with `name, amount, quantity, splitMode` and `expenseEntryShares` (`email, percentage,
  fixedAmount, parts, isLocked`). The editor (`expense_entry_widget.dart`) already does Equal/Shares/%/Exact.
- **Favorites are real.** `Group.isFavorite` (per-member `group_member.isFavorite`).
- **Statistics, invite, QR, friend requests, multi-mode split** all already have screens (see map below).

So the only **net-new feature** is the **Tap to Claim** interaction (Screen 9) — and even that builds on the
existing `expense_entry_share` model (see [Tap to Claim](#tap-to-claim--the-one-new-feature)).

## Architecture (the rules every task must follow)
| Concern | What the app uses | Implication for redesign work |
|---|---|---|
| UI framework | Flutter, **Material 3** | Style via `ColorScheme`/`ThemeData`, **not** hard-coded hex. Land the new palette in the theme. |
| Theming | `getThemeData()` in `lib/widgets/theme_builder.dart`, seeded `ColorSeed.blue`, **light + dark** | The new look is primarily a change *here*. Must produce **both light and dark**. The prototype is light-only — derive dark. |
| State | **Riverpod** w/ codegen (`*.g.dart`, `riverpod_generator`) | Reuse existing providers/notifiers. Run `build_runner` after provider changes. Don't hand-write `.g.dart`. |
| Routing | **go_router** `StatefulShellRoute.indexedStack`, 3 branches (group/friend/setting) in `lib/navigation.dart` | Routes already exist (paths in the map). Restyle the pages they point to; don't re-architect nav. |
| Backend | **Supabase** (Postgres + views + RLS); **Firebase only for FCM push** | Data shapes come from Supabase selects (`*SelectString` consts on models). Don't change queries for a restyle. |
| i18n | **`AppLocalizations`** (en + de), `lib/l10n/*.arb`-generated | **All visible copy must be l10n keys**, never hard-coded English. New copy = add keys to en + de. |
| Currency/format | `helper/helper.dart` (`roundCurrency`, formatters) | Reuse existing formatting helpers. |

## Fidelity
**High-fidelity** on layout, spacing, hierarchy, and interaction. See `DESIGN_SPEC.md` for exact values.
**Adopt the prototype's look fully** — indigo `#5750E6`, warm neutrals, and the Bricolage/Hanken type pairing —
in **both light and dark**. (This is a UI restyle of the existing Deun product, not a brand/identity change.)

---

## Screen → code map
Each prototype screen and its existing implementation + go_router path. "Restyle" = update existing widget to
match `DESIGN_SPEC.md`. Full paths are under `lib/`.

| # | Prototype screen | Existing file(s) | Route | Work |
|---|---|---|---|---|
| 1 | Login / Sign-up | `pages/auth/login_screen.dart`, `pages/auth/sign_in.dart`, `auth_gate.dart` | (auth gate) | Restyle |
| 2 | Password recovery | `pages/auth/update_password.dart` | `/update-password` | Restyle |
| 3 | Onboarding username | `pages/auth/onboarding_screen.dart` | (post-signup) | Restyle |
| 4 | Home · Groups | `pages/groups/presentation/group_list.dart` | `/group` | Restyle + favorite sort |
| 5 | Home · Friends | `pages/friends/presentation/friend_list.dart` (+ `pending_request_list`, `requested_friendship_list`) | `/friend` | Restyle |
| 6 | Home · Settings | `pages/settings/setting.dart` | `/setting` | Restyle |
| 7 | Group detail | `pages/groups/presentation/group_detail.dart` (+ `group_detail_list.dart`) | `/group/details` | Restyle + claim entry points |
| 8 | Expense editor (quick + itemized) | `pages/expenses/presentation/expense_entry_widget.dart`, `expense_detail.dart` | `/group/details/expense` | Restyle |
| 9 | **Tap to Claim** | **none — NEW** | new child route under `/group/details` | **Build** |
| 10 | Settle up | `pages/groups/presentation/group_detail_payment.dart` | `/group/details/payment` (modal) | Restyle |
| 11 | Expense detail (read) | `pages/expenses/presentation/expense_detail.dart` | `/group/details/expense` | Restyle |
| 12 | New / Edit group | `pages/groups/presentation/group_detail_edit.dart` | `/group/edit` | Restyle |
| — | Invite group | `pages/groups/presentation/group_invite_page.dart` | `/group/share` (modal) | Restyle |
| 13 | Group statistics | `pages/statistics/group_statistics_page.dart` (+ `month_detail_bottom_sheet`, `category_detail_bottom_sheet`) | `/group/details/statistics` | Restyle |
| 14 | Personal statistics | `pages/statistics/personal_statistics_page.dart` | `/setting/statistics` | Restyle |
| 15a | Add friend | `pages/friends/presentation/friend_add_page.dart` (+ `search_result_list`, `contact_suggestion_list`) | `/friend/add` | Restyle |
| 15b | QR (mine + scan) | `pages/friends/presentation/friend_qr_page.dart` | `/friend/qr` | Restyle |
| — | Receipt scan sheet | `pages/expenses/presentation/receipt_scanner_sheet.dart` | (sheet) | Restyle |
| — | Category / Paid-by / Date pickers | inside `expense_entry_widget.dart` | (inline/sheets) | Restyle |
| — | Modal sheet wrapper | `widgets/modal_bottom_sheet_page.dart` | — | Reuse |

Mappings marked across two files (e.g. 8/11 both touch `expense_detail.dart`) — confirm which file owns the
read vs edit view when you open it; both are large (20–32 KB).

---

## Theme & tokens — how to land the new look
The redesign is **mostly a theme change**, applied in `lib/widgets/theme_builder.dart`. The existing
`getThemeData()` already hand-tunes M3 surfaces for light + dark and sets button/sheet/card/chip themes —
extend it, don't replace its structure.

1. **Seed & accent.** Prototype accent is `#5750E6` (indigo). Change the app seed (in `navigation.dart`
   `getThemeData(..., ColorSeed.blue.color, ...)`) to this, or add a `ColorSeed` entry. `primary` ≈ `#5750E6`,
   `primary` tint surface ≈ `#ECEBFC`.
2. **Surfaces → warm neutrals.** Prototype uses warm off-whites: app bg `#F4F3EF`, card `#FFFFFF`, bars/sheets
   `#FBFAF7`, field fills `#F1EFE9`/`#EAE8E1`. Map these onto the existing `surface` / `surfaceContainer*`
   slots (today they're cool grays like `#efedee`). Derive dark equivalents in the same `if (dark)` block.
3. **Semantic colors.** Success/owed `#1A8F5E` (dark-surface `#4ED99B`); danger/owe `#D85A47` (`#F2937F`);
   warning/unclaimed `#C98A2E`. Add as theme extensions or named constants (not inline literals) so dark mode
   and reuse work.
4. **Group colors.** Groups already store `colorValue`; the prototype's 6-swatch palette
   (`#5750E6/#2F73D9/#E0853D/#D45A8A/#E0735A/#B85C9E` + light tints) should become the color picker options in
   `group_detail_edit.dart`. The group hero card tints by `Group.colorValue`.
5. **Member avatar colors.** Prototype assigns a stable color per member; derive deterministically from email/id.
6. **Typography.** Adopt **Bricolage Grotesque** (display/amounts, `-0.02em`) + **Hanken Grotesk** (body):
   add the fonts (pubspec `google_fonts` or bundled), set the app `textTheme` in `theme_builder.dart`, use
   Bricolage for headings/amount displays only. All amounts use tabular figures.
7. **Shape & elevation.** Cards 18–26 radius, soft shadow `0 2px 4px rgba(20,18,12,.04)`; sheets already 28
   top-radius w/ drag handle (matches); pills/FAB already `StadiumBorder` (matches). Primary button shadow
   `0 12px 22px -10px rgba(87,80,230,.5)`.

> Full numeric tokens, per-screen layouts, and verbatim copy live in `DESIGN_SPEC.md`.

---

## Tap to Claim — the one new feature
**What it is:** for an itemized expense, each member claims the individual line-items they consumed (a unit
solo, or a unit split with others), instead of the whole bill being split evenly. See Screen 9 in
`DESIGN_SPEC.md` for the full UI (persona summary card, per-unit chips, "take one" / "split one", confirm sheet).

**How it maps to existing data:** claiming = editing an expense's `expense_entry_share` rows — adding/removing
the current user (and split partners) on an entry's shares. The summary, progress, and per-member totals are
derived exactly like `Expense.groupMemberShareStatistic` already does.

**Data model — build it as designed (decided):** the prototype models claims **per unit** (an entry of
`quantity: N` where each of the N units is claimed by a *different* subset — e.g. unit 1 = Sam alone, unit 2 =
Priya+Jonas). Implement this faithfully via **unit-level entries**: represent each claimable unit as its own
`ExpenseEntry` (`quantity: 1`) so its `expense_entry_share` rows hold that unit's claimers (split = `unit /
claimers`). **Supabase schema/write-path changes are approved** for this. Adapt the receipt-parser write path
to emit per-unit entries. This is the only task that touches the backend; everything else is presentation.

## Cross-cutting rules
- **Dark mode:** every restyle must look right in both brightnesses — pull colors from `Theme.of(context).colorScheme`
  / theme extensions, never hard-code the prototype's light hexes in a widget.
- **l10n:** every string is an `AppLocalizations` key. New copy → add to en + de `.arb`, regenerate.
- **Riverpod:** reuse existing providers; after editing a provider/notifier run `dart run build_runner build`.
- **go_router:** navigate via existing routes/paths; the new claim screen is a new child route under `/group/details`.
- **No schema/query changes** for pure restyles — only Tap-to-Claim option (A) may require them.

## Decisions (resolved)
1. **Aesthetic scope:** ✅ **Adopt the prototype's full look** — indigo `#5750E6` + warm neutrals +
   Bricolage/Hanken fonts. (Restyle of the existing product, brand unchanged.)
2. **Dark mode:** ✅ **Required** — derive dark variants of the new palette in `theme_builder.dart`; every
   restyled screen must look right in both brightnesses.
3. **Tap-to-Claim data model:** ✅ **Build as designed** — per-unit claims via unit-level `ExpenseEntry`
   rows. **Supabase schema changes are approved.**

## Files in this bundle
- `README.md` — this file (codebase map + rules + decisions).
- `DESIGN_SPEC.md` — the visual reference (tokens, every screen's layout & copy, state, interactions).
- `ROADMAP.md` — restyle + build tasks, sequenced for autonomous coding loops, each pointing at the file to edit.
- `Deun Redesign v2.dc.html` + `support.js` — the interactive prototype. Open in a browser (keep them together)
  to click through every flow. It's a **reference**, not code to port.
