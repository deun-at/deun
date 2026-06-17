# Deun Redesign — Implementation Roadmap (Flutter)

A restyle-and-build plan for landing the prototype in the existing `deun-at/deun` app, **structured for
autonomous coding loops**. Most tasks **restyle an existing widget**; only Epic 3 (Tap to Claim) is net-new.
Work E0 first (it sets the look for everything); the rest can largely parallelize by feature area.

## How to use this with loops
- **One task = one loop iteration.** Each has an ID, the **file to edit**, scope, deps, and acceptance.
- **Global definition of done:** matches `DESIGN_SPEC.md`; **looks right in light AND dark**; all copy via
  `AppLocalizations` (add en+de keys for new strings); `flutter analyze` clean; if a provider/notifier
  changed, `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`.
- **Reference:** click the prototype `Deun Redesign v2.dc.html`; pull exact values from `DESIGN_SPEC.md`.
- **Don't:** hard-code the prototype's light hex in widgets (use `Theme.of(context).colorScheme` / theme
  extensions); change Supabase queries or `*SelectString` for a restyle; rebuild balances/OCR/favorites
  (they exist — see README corrections).
- **Decided (no longer blocked):** adopt the full prototype look (indigo + warm neutrals + Bricolage/Hanken),
  **dark mode required**, Tap-to-Claim built **as designed** (per-unit, unit-level `ExpenseEntry` rows,
  Supabase schema changes approved). Tasks below reflect these.

Suggested labels: `theme`, `restyle`, `feature`, `data`, `polish`.

---

## E0 — Foundation (do first, in order)

**E0-T1 · New palette in the theme** · `lib/widgets/theme_builder.dart` (+ seed in `lib/navigation.dart`)
Map the prototype palette onto the M3 `ColorScheme`: seed → `#5750E6`; `surface`/`surfaceContainer*` → warm
neutrals (`#F4F3EF`/`#FBFAF7`/`#FFFFFF`/`#F1EFE9`); keep the existing light/dark structure and **derive dark
equivalents** (required). Don't restyle screens yet.
*Done:* app boots; existing screens visibly pick up the new surfaces/accent in both brightnesses; no analyze errors.
✅ **done · 5ab16ad** — `kBrandSeed` (#5750E6) wired in `navigation.dart`; warm-neutral light + near-black dark
surfaces mapped in `theme_builder.dart`; unit-tested exact slot values (light+dark); analyze clean, 213 tests green.
(Branch `feat/redesign`. Prereq commit `851cf95` fixed a pre-existing `toCurrency` baseline breakage in statistics
that was failing analyze — unrelated to the redesign.)

**E0-T2 · Semantic + group colors** · `lib/widgets/theme_builder.dart` (ThemeExtension) + `lib/constants.dart`
Add a `ThemeExtension` for semantic colors (success `#1A8F5E`/`#4ED99B`, danger `#D85A47`/`#F2937F`, warning
`#C98A2E`, on-dark variants) and a deterministic member-avatar-color helper. Add the 6-swatch group palette as
the group color-picker options.
*Done:* helpers importable; a sample owed/owe label uses them and flips correctly in dark.
✅ **done · 223fe2f** — `SemanticColors` ThemeExtension (success/danger/warning + payback pair, light+dark) in
`theme_builder.dart`; `memberAvatarColor()` (stable FNV-1a hash) + `kMemberAvatarPalette` + `kGroupColorPalette`
(6 swatches) in `constants.dart`; 12 tests incl. dark-flip; analyze clean, 225 tests green.
*v0:* payback-dark pair `#1E3A2C`/`#5FA882` (no spec dark value); group tints omitted (hero tints via surface).

**E0-T3 · Typography** · `lib/widgets/theme_builder.dart` + `pubspec.yaml`
Add Bricolage Grotesque + Hanken Grotesk (`google_fonts` or bundled), set `textTheme` (Hanken body, Bricolage
for `displayLarge/headline*`/amount styles, `-0.02em`), tabular figures for amounts.
*Done:* headings render in Bricolage, body in Hanken, across light/dark.
✅ **done · cabede5** — `textTheme` in `theme_builder.dart` (both brightnesses): Hanken base via
`GoogleFonts.hankenGroteskTextTheme`, Bricolage on display*/headline*/titleLarge with `letterSpacing = size×-0.02`
+ `FontFeature.tabularFigures()` on display+headline; 5 tests; analyze clean, 230 tests green.
*v0 sizes:* display 57/45/40, headline 30/28/24, titleLarge 19.

**E0-T4 · Shared restyle widgets** · new under `lib/widgets/`
Build the reused pieces so screens compose them: `MemberAvatar` (+ ring/border), `AvatarStack`, `MoneyText`
(tabular, semantic color), `BalancePill`, `AppSegmentedControl`, `SectionLabel`, `SoftCard`, `Stepper`,
`SheetScaffold` (drag handle + warm surface), `ProgressBar`. Match `DESIGN_SPEC.md` radii/shadows/type.
*Done:* a throwaway gallery route renders each in light+dark.
✅ **done · 39b66ae** — 10 widgets under `lib/widgets/restyle/` (MemberAvatar, AvatarStack, MoneyText,
BalancePill, AppSegmentedControl, SectionLabel, SoftCard, StepperControl, SheetScaffold, ProgressBar) +
`lib/widgets/dev/widget_gallery_page.dart` at route `/dev/gallery`; 22 tests; analyze clean, 252 tests green.
*v0:* SoftCard drops light shadow in dark; rings 2px; StepperControl uses GestureDetector (test-env shader);
BalancePill tint α=0.14. *QA:* eyeball `/dev/gallery` in light+dark.

---

## E1 — Groups

**E1-T1 · Groups list** · `lib/pages/groups/presentation/group_list.dart`
Greeting header + avatar; dark overall-balance hero (aggregate from `Group` summaries); group cards (tinted
icon by `colorValue`, name, favorite star toggle → existing `isFavorite`, member `AvatarStack`, balance
lead/amount via `MoneyText`); favorite sort order. Star tap must not open the card.
*Deps:* E0-T4. *Screen 4.*
✅ **done · 67a894f** — restyled `group_list.dart` + new `group_list_item.dart` (greeting header, dark balance
hero, tinted-icon cards w/ star toggle, AvatarStack footer, MoneyText balance); pure `sortGroups` +
`aggregateOverallBalance` in `group_list_view_model.dart` (unit-tested); 13 tests; 12 en+de l10n keys; analyze
clean, 265 green. *v0:* hero = ink `onSurface` (light)/`surfaceBright` (dark); amount=net, chips=gross owed/owe.
*QA:* greeting/hero/star-resort in light+dark.

**E1-T2 · Group detail + ledger** · `group_detail.dart`, `group_detail_list.dart`
Color hero (balance, member stack, Settle-up → `/group/details/payment`), Statistics + Invite quick actions,
day-grouped ledger with the 3 row types (quick → read detail; itemized → Tap-to-Claim w/ accent bar + claim
pill + claimer avatars + unclaimed meta; payback green row), empty state, Scan + Add-expense FABs.
*Deps:* E1-T1. *Screen 7. (Claim row taps can stub until E3.)*
✅ **done · b20f81f** — restyled `group_detail.dart` (color hero, Statistics/Invite actions) + `group_detail_list.dart`
(day-grouped ledger, 3 row types) + new `group_ledger.dart` (pure `classifyLedgerRow`/`groupExpensesByDay`,
unit-tested); pagination/realtime/routes preserved; 15 tests; 6 en+de keys; analyze clean, 280 green.
*Row types:* payback=`isPaidBackRow`, itemized=`entries>1`, else quick. *Claim tap STUB→read-detail* (`TODO(E3)`).
*QA:* hero tint, itemized claim pill/avatars, payback green row in light+dark.

**E1-T3 · New / Edit group** · `group_detail_edit.dart`
Name, color swatch row (retints icon, writes `colorValue`), member toggles + add-guest, Simplified/Detailed
radio (`simplifiedExpenses`), sticky Create/Save.
*Deps:* E0-T4. *Screen 12.*
✅ **done · ec3573a** — restyled `group_detail_edit.dart` (name + retinted icon preview, 6-swatch `kGroupColorPalette`
row → `colorValue`, reused member search/add-guest, Simplified/Detailed cards → `simplifiedExpenses`, sticky
Create/Save); pure `selectedGroupSwatchIndex` helper; 8 tests; 9 en+de keys; analyze clean, 288 green.
*v0:* new groups default Detailed; footer uses `surface` (spec bar tone `surfaceContainerLow` — device-tweakable).
*QA:* swatch select retints preview, mode toggle, create vs save in light+dark.

**E1-T4 · Invite sheet** · `group_invite_page.dart`
Group link + QR + Share, in the restyled `SheetScaffold`.
*Deps:* E0-T4. *Route `/group/share`.*
✅ **done · 871546a** — restyled `group_invite_page.dart` into `SheetScaffold` (drag handle, warm surface, title +
close, QR on white card, copyable link row, sticky Share footer); link/QR/Share logic + `/group/share` route
unchanged; 4 tests; 3 en+de keys; analyze clean, 292 green. *v0:* QR kept dark-on-white in dark mode (scannability).
*QA:* sheet rise, QR scan, copy-link snackbar, Share in light+dark.

---

## E2 — Expenses

**E2-T1 · Expense editor — Quick split** · `expense_entry_widget.dart` (+ `expense_detail.dart` host)
Mode segmented (Quick/Itemized); category tile (→ category sheet), big amount (→ keypad sheet), description,
paid-by/when rows, 4-way split segmented (`SplitMode`), allocation bar + remaining indicator, per-member rows
(include/avatar/stepper/amount). Wire to existing `expenseEntryShares`. Dirty-guard → Discard sheet.
*Deps:* E0-T4. *Screen 8 (quick).*
✅ **done · ddcc86b + 4d4e25e** — restyled split section (`SplitMode` segmented, `ProgressBar` allocation bar +
semantic remaining indicator, per-member include/avatar/`StepperControl`/amount via `MoneyText`; pure
`split_allocation.dart`) + input tiles (category/amount/description/paid-by/when as `SoftCard` tiles opening the
existing pickers) + PopScope dirty-guard → `discard_sheet.dart`. Split math untouched; 20 tests; 10 en+de keys;
analyze clean, 312 green. *v0:* SplitMode bound to the REAL 3-way model (amount/%/shares), not the spec's 4-way
(Equal/Exact are amount-mode variants) — changing the enum/DB is forbidden; amount stays inline-editable (keypad
sheet = E2-T3). **Carry to E2-T2:** explicit Quick/Itemized top segmented toggle (mode today derives from entry
count; coheres with the itemized view). *QA:* tiles, split modes, remaining over/under/ok, discard sheet in light+dark.

**E2-T2 · Expense editor — Itemized** · `expense_entry_widget.dart`
Total-from-items + Scan; item cards (editable name/unit/qty/line total/delete via `ExpenseEntry`), add-item,
info callout, "Add & share for claiming" CTA.
*Deps:* E2-T1. *Screen 8 (itemized).*

**E2-T3 · Category / Paid-by / Date / Keypad sheets** · within `expense_entry_widget.dart` + `SheetScaffold`
Category grid uses `ExpenseCategory` (`getIcon`/`getColor`/`getDisplayName`); paid-by member list; date
options; amount keypad (2-dec/7-digit limit).
*Deps:* E0-T4. *Sheets.*

**E2-T4 · Expense detail (read)** · `expense_detail.dart`
Summary card (icon/title/cat·date/total/payer/your net), itemized "Review & claim" banner (→ E3), per-member
breakdown + tags.
*Deps:* E1-T2. *Screen 11.*

**E2-T5 · Receipt scan sheet** · `receipt_scanner_sheet.dart`
Restyle the scanner UI (corner brackets + scan line + detected-items preview) feeding the existing Gemini
parser → itemized editor. **OCR already works — UI only.**
*Deps:* E2-T2. *Sheet.*

---

## E3 — Tap to Claim (the one new feature)

**E3-T1 · Claim data model — per-unit entries** · `data:` `expense_entry_model.dart` / repository / Supabase migration
Build claims **as designed**: each claimable unit becomes its own `ExpenseEntry` (`quantity: 1`); claim /
unclaim / split-one = mutating that unit's `expense_entry_share` rows (split = `unit / claimers`). Add the
Supabase migration + adapt the write path (incl. receipt-parser output) to emit per-unit entries. Add a
Riverpod notifier for claim state; unit-test the cost math. **Schema changes approved.**
*Deps:* E2-T2. *Blocks the rest of E3.*

**E3-T2 · Claim screen — layout & summary** · new page `lib/pages/expenses/presentation/claim_page.dart` + new
go_router child route under `/group/details`
Header (merchant + presence pulse + edit), persona switcher, dark summary card (your share, progress, unclaimed,
per-member totals). Route from itemized ledger rows + the read-detail banner.
*Deps:* E3-T1, E1-T2. *Screen 9.*

**E3-T3 · Claim items — chips & actions** · `claim_page.dart`
Per-unit chips (claimed avatars + name/"split · €X"; open dashed "take one"), tap to claim/unclaim, "Split one"
inline member picker (per-unit cost), unclaimed callout + Nudge, sticky Confirm → success sheet.
*Deps:* E3-T2. *Screen 9.*

---

## E4 — Settle up

**E4-T1 · Payment sheet** · `lib/pages/groups/presentation/group_detail_payment.dart`
Color hero (overall), You-pay (Pay → method detail) / Owes-you (Remind) sections, method cards filtered by
payee's `paypalMe`/`iban` (from `GroupSharesSummary`), confirm → settled. **Settlement amounts already
computed in `group_model.dart` — bind, don't recompute.**
*Deps:* E0-T4. *Screen 10, route `/group/details/payment`.*

**E4-T2 · Friend detail sheet** · within `friend_list.dart`
Friend balance + pay-back options (PayPal / Copy IBAN / Mark paid) + remove friend.
*Deps:* E5-T1. *Sheet.*

---

## E5 — Friends

**E5-T1 · Friends list** · `friend_list.dart` (+ `pending_request_list.dart`, `requested_friendship_list.dart`)
Header QR + add buttons; incoming (accept/decline), outgoing (cancel), all-friends with balance labels; tab
badge already wired in `navigation.dart`.
*Deps:* E0-T4. *Screen 5.*

**E5-T2 · Add friend** · `friend_add_page.dart` (+ `search_result_list.dart`, `contact_suggestion_list.dart`)
Search by `username#code`, live results, contacts, Add/Requested buttons.
*Deps:* E5-T1. *Screen 15a.*

**E5-T3 · QR** · `friend_qr_page.dart`
My-code (QR + profile + Copy/Share) / Scan viewfinder segmented tabs.
*Deps:* E5-T1. *Screen 15b.*

---

## E6 — Statistics

**E6-T1 · Group statistics** · `lib/pages/statistics/group_statistics_page.dart` (+ `month_detail_bottom_sheet.dart`,
`category_detail_bottom_sheet.dart`)
Range control + period stepper, color summary, monthly trend bars (→ month sheet), members paid-vs-fair bars,
category bars (→ category sheet, using `ExpenseCategory` colors).
*Deps:* E1-T2. *Screen 13.*

**E6-T2 · Personal statistics** · `personal_statistics_page.dart`
Dark paid/share card, monthly bars, by-group list.
*Deps:* E0-T4. *Screen 14, route `/setting/statistics`.*

---

## E7 — Auth & Settings

**E7-T1 · Login / Sign-up** · `pages/auth/login_screen.dart`, `sign_in.dart`, `auth_gate.dart`
Social buttons, email/password, mode switch, forgot-password. Keep existing auth logic.
*Deps:* E0-T4. *Screen 1.*

**E7-T2 · Recovery + Onboarding** · `update_password.dart`, `onboarding_screen.dart`
Recovery email screen; onboarding username (sanitized, `#code` suffix, live handle) + display name.
*Deps:* E7-T1. *Screens 2–3.*

**E7-T3 · Settings + sheets** · `pages/settings/setting.dart` (+ `navigation.dart` for themeMode)
Profile card + form (copy username, language → sheet), settings list (notifications toggle, **Appearance →
System/Light/Dark picker sheet**, privacy, contact), personal-stats entry, delete-account (type-DELETE sheet),
language sheet, sign out. Wire Appearance to the app `themeMode`: replace the hard-coded
`ThemeMode.system` in `navigation.dart` with a Riverpod `themeModeProvider` (persist the choice) the picker sets.
*Deps:* E0-T4. *Screen 6.*

---

## E8 — Polish (trails the screens it covers)
- **E8-T1 Dark-mode audit:** every redesigned screen in dark — no hard-coded light hex leaked through.
- **E8-T2 l10n audit:** no literal strings; en+de keys exist for all new copy; regenerated.
- **E8-T3 Motion:** sheet rise, scrim fade, scan sweep, presence pulse; Android predictive-back still works.
- **E8-T4 Empty/edge states:** empty ledger, settled groups, fully-claimed vs unclaimed, over/under split,
  no-friends/no-requests.
- **E8-T5 a11y & touch targets:** ≥48dp hit areas, semantics labels, contrast on muted text in both themes.

---

## Dependency cheat-sheet
```
E0 (theme/tokens/widgets) ──► everything
  ├─ E1 Groups ──► E2 Expenses ──► E3 Tap-to-Claim (per-unit; Supabase migration)
  ├─ E4 Settle (binds existing balances)
  ├─ E5 Friends ──► E4-T2
  ├─ E6 Statistics
  └─ E7 Auth & Settings
E8 polish trails each screen.
```

## Reminders
- **All decisions resolved** — no blocked tasks: full prototype look, dark mode required, Tap-to-Claim per-unit
  (schema changes approved).
- **Already built — restyle only:** balances/settlement, receipt OCR, itemized data, favorites, statistics,
  invite, QR, friend requests, multi-mode split, routing, badges.
- **Net-new code:** Epic 3 only (+ its route and possibly a migration).
- Keep prototype copy verbatim (via l10n) unless product says otherwise.
