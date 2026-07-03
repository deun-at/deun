# F99 · Button unification (apply presets app-wide)

**Goal:** Replace remaining raw Material buttons (`FilledButton*`, `ElevatedButton`,
`OutlinedButton*`) that represent primary/secondary actions with the existing v3
presets in `lib/widgets/restyle/` (`PrimaryButton`, `SecondaryButton`,
`DashedGhostButton`, `HeaderIconButton`). Genuine text links and platform dialog
`Cancel`/`OK` actions stay as `TextButton`.

**Status:** PARTIAL — Slice 1 (receipt scanner sheet) DONE. Remainder listed below.

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

### REMAINING

**Friends**
- `friend_accept_page.dart` L124 `FilledButton` close → **P**; L168 `OutlinedButton` cancel → **S**; L175 `FilledButton` accept (has spinner) → **P** (loading)
- `contact_suggestion_list.dart` L118 `FilledButton.tonal` open-settings (left-aligned, non-full-width) → **SPECIAL** (compact) 
- `requested_friendship_list.dart` L57 `FilledButton` error-tinted trailing (compact list-tile action) → **SPECIAL** (compact, error color)
- `friend_detail_sheet.dart` L262 dialog cancel → **KEEP**; L266 `FilledButton` error confirm (dialog action) → **KEEP** (platform dialog) / or **P**-danger if desired
- `friend_add_row.dart` L100 `FilledButton` compact request pill → **SPECIAL** (compact inline)
- `friend_qr_page.dart` L535 `FilledButton.tonal` retry → **S**
- `friend_list.dart` L287 `FilledButton` accept (compact icon+label) → **SPECIAL**; L330 `OutlinedButton` cancel (compact, error) → **SPECIAL**

**Groups**
- `group_detail_payment.dart` L201 `FilledButton.icon` pay (compact) → **SPECIAL**; L277 gray tonal remind pill → **SPECIAL**
- `group_detail_edit.dart` L177 dialog cancel → **KEEP**; L181 `FilledButton` error confirm → **KEEP** (dialog)
- `group_invite_page.dart` L113 `TextButton.icon` copy → **KEEP** (link); L130 `TextButton.icon` show/hide QR → **KEEP** (link)
- `group_list.dart` L152 `TextButton.icon` "New" (section trailing) → **KEEP** (compact link)
- `group_detail.dart` L467 `FilledButton` on-hero contextual-color → **SPECIAL** (hero-tinted)
- `group_join_page.dart` L215 `FilledButton.icon` join (spinner) → **P** (loading)

**Expenses**
- `expense_detail.dart` L240 dialog cancel → **KEEP**; L244 `FilledButton` error confirm → **KEEP** (dialog); L349 `FilledButton.icon` Scan (ink-tinted compact) → **SPECIAL**

**Settings**
- `settings_sheets.dart` L302 `OutlinedButton` cancel + L309 `FilledButton` error confirm (Expanded row) → **S** + **P**-danger (candidate next slice)
- `setting.dart` L210 dialog cancel → **KEEP**; L214 `FilledButton` error sign-out (dialog) → **KEEP** (dialog)
- `contact.dart` L108 `FilledButton` submit → **P**

**Auth**
- `sign_in.dart` — social buttons already use SecondaryButton; any `TextButton` "forgot password" → **KEEP** (link)

**Shared/dev**
- `helper.dart`, `theme_builder.dart`, `widget_gallery_page.dart`, restyle sheets — dev/gallery or already-preset; **KEEP**/out of scope.

Notes on SPECIAL: compact list-tile / pill actions and contextual-color (hero/ink)
buttons do not map onto the full-width presets without a size/color variant. They
are deferred rather than forced, to avoid inventing a new variant this slice.
Candidate clean next slice: `settings_sheets.dart` + `contact.dart` + `friend_qr_page.dart`
+ `friend_accept_page.dart` + `group_join_page.dart` (all full-width or two-button-row shapes).

## Live web sign-off: PENDING (browser harness unavailable).
