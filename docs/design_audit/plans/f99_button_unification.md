# F99 · Button unification (apply presets app-wide)

**Goal:** Replace remaining raw Material buttons (`FilledButton*`, `ElevatedButton`,
`OutlinedButton*`) that represent primary/secondary actions with the existing v3
presets in `lib/widgets/restyle/` (`PrimaryButton`, `SecondaryButton`,
`DashedGhostButton`, `HeaderIconButton`). Genuine text links and platform dialog
`Cancel`/`OK` actions stay as `TextButton`.

**Status:** FULLY DONE — Slice 1 (receipt scanner) + Slice 2 (clean full-width /
two-button rows) + Slice 3 (compact / danger / contextual-color variants) all
landed. Every non-text-link primary/secondary action now uses a preset. The only
remaining raw buttons are genuine text links + platform-dialog Cancel/OK actions,
which stay `TextButton` by design.

### Slice 3 — Preset variants + all SPECIAL sites — DONE

`PrimaryButton` / `SecondaryButton` gained a small, coherent set of optional
params (no new widget classes):
- `compact` (both): tighter StadiumBorder pill, no drop-shadow, intrinsic width —
  for inline list-tile / trailing-row actions (COMPONENTS §"Stadium pills").
- `background` + `foreground` (PrimaryButton): contextual fill/label override for
  danger (`colorScheme.error`/`onError`), on-hero (`onHero`/`heroSurface`), and
  ink (`ink.ink`/`ink.onInk`) pills. Shadow tint tracks the override.
- `foreground` (SecondaryButton): tints border+label+icon (danger cancel).
- `background` (SecondaryButton): neutral tonal fill, drops the hairline border
  (the gray "Remind" pill). All via theme tokens / SemanticColors — no hex.

Sites converted this slice:
- `settings_sheets.dart` delete-account footer → **S** cancel + **P**-danger confirm.
- `friend_add_row.dart` Add pill → **P** compact.
- `contact_suggestion_list.dart` open-settings → **S** compact.
- `requested_friendship_list.dart` cancel (error) → **P** compact danger + icon.
- `friend_list.dart` accept → **P** compact + icon; cancel (error) → **S** compact
  danger + icon.
- `group_detail_payment.dart` Pay → **P** compact + icon; Remind gray pill → **S**
  compact tonal (surfaceContainer bg).
- `group_detail.dart` on-hero settle-up → **P** (background:onHero, foreground:heroSurface).
- `expense_detail.dart` Scan pill → **P** compact ink (background:ink.ink).

Tests: `primary_button_test.dart` gained coverage for danger `background` (fill +
shadow tint), `compact` (no shadow, shorter), SecondaryButton `foreground`
(border tint), `background` (tonal, no border), and compact height.
`group_detail_payment_test.dart` updated Pay→PrimaryButton, Remind→SecondaryButton.

## Constraints
- No copy changes — reuse existing l10n labels.
- Colors via presets/theme tokens only — no inline hex.
- Reuse the 4 existing presets; do NOT create new button widgets.
- Preserve every button's `onPressed`, enabled/disabled state, label, icon, and `ValueKey`.
- Never weaken/delete tests; update any that asserted a Material button type at a converted site.

---

## Inventory (classification)

Legend: **P** → PrimaryButton, **S** → SecondaryButton, **G** → DashedGhostButton,
**KEEP** → genuine text link / platform dialog action (stays TextButton),
**SPECIAL** → compact/inline pill or contextual-color button; convert with care or defer.

### Slice 1 — Receipt scanner sheet — DONE
`lib/pages/expenses/presentation/receipt_scanner_sheet.dart`
- L161 `FilledButton.icon` `receipt_take_photo` → **P** (icon)
- L168 `FilledButton.tonalIcon` `receipt_choose_gallery` → **S** (icon)
- L434 `OutlinedButton.icon` `receipt_retake` (Expanded) → **S** (icon, fullWidth:false)
- L444 `FilledButton` `receipt_confirm` (Expanded flex:2) → **P** (fullWidth:false)

### Slice 2 — Clean full-width / two-button rows — DONE
- `friend_accept_page.dart` — close `FilledButton` → **P** (fullWidth:false); cancel
  `OutlinedButton` → **S** (fullWidth:false); accept `FilledButton`+spinner → **P**
  (loading:_accepting, fullWidth:false). Centered Row → kept intrinsic width.
- `friend_qr_page.dart` `_ErrorState` retry `FilledButton.tonal` → **S** (fullWidth:false).
- `group_join_page.dart` join `FilledButton.icon`+spinner → **P** (icon: login,
  loading:_joining, fullWidth:false).
- `contact.dart` submit `FilledButton` → **P** (fullWidth:false; kept in Align.centerRight).

Not converted this slice: `settings_sheets.dart` delete-account row. Its confirm is
`backgroundColor: colorScheme.error` (danger). PrimaryButton has no color override,
so converting it would silently drop the error tint — that needs a **P-danger** color
variant (deferred). The paired cancel stays raw too, to avoid a mismatched pair
(preset next to a raw error FilledButton) until the danger variant lands.

### SPECIAL sites — ALL converted (Slice 3)

Every SPECIAL compact-pill / contextual-color / danger button now maps onto a
preset via the `compact` / `background` / `foreground` params.

**Friends**
- `friend_accept_page.dart` — DONE (Slice 2).
- `contact_suggestion_list.dart` open-settings → **S** compact — DONE.
- `requested_friendship_list.dart` error-tinted cancel → **P** compact danger — DONE.
- `friend_detail_sheet.dart` dialog cancel + error confirm → **KEEP** (platform dialog).
- `friend_add_row.dart` request pill → **P** compact — DONE.
- `friend_qr_page.dart` — retry DONE (Slice 2).
- `friend_list.dart` accept → **P** compact; cancel (error) → **S** compact danger — DONE.

**Groups**
- `group_detail_payment.dart` pay → **P** compact; remind gray pill → **S** compact tonal — DONE.
- `group_detail_edit.dart` dialog cancel + error confirm → **KEEP** (dialog).
- `group_invite_page.dart` copy / show-hide QR → **KEEP** (links).
- `group_list.dart` "New" section trailing → **KEEP** (compact link).
- `group_detail.dart` on-hero settle-up → **P** (onHero/heroSurface) — DONE.
- `group_join_page.dart` — join DONE (Slice 2).

**Expenses**
- `expense_detail.dart` dialog cancel + error confirm → **KEEP** (dialog); Scan pill → **P** compact ink — DONE.

**Settings**
- `settings_sheets.dart` delete-account footer: cancel → **S**, confirm → **P**-danger — DONE.
- `setting.dart` dialog cancel + error sign-out → **KEEP** (dialog).
- `contact.dart` — submit DONE (Slice 2).

**Auth**
- `sign_in.dart` — social buttons already SecondaryButton; "forgot password" → **KEEP** (link).

**Shared/dev**
- `helper.dart`, `theme_builder.dart`, `widget_gallery_page.dart`, restyle sheets — dev/gallery or already-preset; **KEEP**/out of scope.

## F99 overall: FULLY DONE

Every non-text-link primary/secondary action across the app now routes through
`PrimaryButton` / `SecondaryButton` (with the small `compact` / `background` /
`foreground` variant set). The only raw buttons left are, by design:
- **KEEP** — genuine text links (`group_invite_page` copy / QR, `group_list` "New")
  and platform-dialog Cancel/OK actions (`friend_detail_sheet`, `group_detail_edit`,
  `expense_detail`, `setting` sign-out). These are correct as `TextButton`.

No holdouts. The preset set stayed small (2 widgets, 3 optional params) per
COMPONENTS §1.

## Live web sign-off: PENDING (browser harness unavailable).
