# F99 · Button unification (apply presets app-wide)

**Goal:** Replace remaining raw Material buttons (`FilledButton*`, `ElevatedButton`,
`OutlinedButton*`) that represent primary/secondary actions with the existing v3
presets in `lib/widgets/restyle/` (`PrimaryButton`, `SecondaryButton`,
`DashedGhostButton`, `HeaderIconButton`). Genuine text links and platform dialog
`Cancel`/`OK` actions stay as `TextButton`.

**Status:** PARTIAL — Slice 1 (receipt scanner) + Slice 2 (clean full-width /
two-button rows) DONE. Remaining are SPECIAL cases needing a new compact/danger/
contextual variant (a later slice) + genuine text links / dialog actions (KEEP).

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

### REMAINING (SPECIAL — need a new variant; deferred to a later slice)

Every REMAINING entry below is either a genuine text link / platform-dialog action
(**KEEP**, correct as TextButton) or a **SPECIAL** compact-pill / contextual-color /
danger button that does not map onto the full-width `PrimaryButton`/`SecondaryButton`
presets without a new size or color variant. None are plain full-width CTAs — those
are all done. Building the compact/danger/hero variants is a separate later slice.

**Friends**
- `friend_accept_page.dart` — DONE (see Slice 2 above).
- `contact_suggestion_list.dart` L118 `FilledButton.tonal` open-settings (left-aligned, non-full-width) → **SPECIAL** (compact) 
- `requested_friendship_list.dart` L57 `FilledButton` error-tinted trailing (compact list-tile action) → **SPECIAL** (compact, error color)
- `friend_detail_sheet.dart` L262 dialog cancel → **KEEP**; L266 `FilledButton` error confirm (dialog action) → **KEEP** (platform dialog) / or **P**-danger if desired
- `friend_add_row.dart` L100 `FilledButton` compact request pill → **SPECIAL** (compact inline)
- `friend_qr_page.dart` — retry DONE (see Slice 2 above).
- `friend_list.dart` L287 `FilledButton` accept (compact icon+label) → **SPECIAL**; L330 `OutlinedButton` cancel (compact, error) → **SPECIAL**

**Groups**
- `group_detail_payment.dart` L201 `FilledButton.icon` pay (compact) → **SPECIAL**; L277 gray tonal remind pill → **SPECIAL**
- `group_detail_edit.dart` L177 dialog cancel → **KEEP**; L181 `FilledButton` error confirm → **KEEP** (dialog)
- `group_invite_page.dart` L113 `TextButton.icon` copy → **KEEP** (link); L130 `TextButton.icon` show/hide QR → **KEEP** (link)
- `group_list.dart` L152 `TextButton.icon` "New" (section trailing) → **KEEP** (compact link)
- `group_detail.dart` L467 `FilledButton` on-hero contextual-color → **SPECIAL** (hero-tinted)
- `group_join_page.dart` — join DONE (see Slice 2 above).

**Expenses**
- `expense_detail.dart` L240 dialog cancel → **KEEP**; L244 `FilledButton` error confirm → **KEEP** (dialog); L349 `FilledButton.icon` Scan (ink-tinted compact) → **SPECIAL**

**Settings**
- `settings_sheets.dart` L302 `OutlinedButton` cancel + L309 `FilledButton` error confirm (Expanded row) → **S** + **SPECIAL** (P-danger). Deferred: confirm needs a P-danger color variant; cancel held with it to avoid a mismatched pair.
- `setting.dart` L210 dialog cancel → **KEEP**; L214 `FilledButton` error sign-out (dialog) → **KEEP** (dialog)
- `contact.dart` — submit DONE (see Slice 2 above).

**Auth**
- `sign_in.dart` — social buttons already use SecondaryButton; any `TextButton` "forgot password" → **KEEP** (link)

**Shared/dev**
- `helper.dart`, `theme_builder.dart`, `widget_gallery_page.dart`, restyle sheets — dev/gallery or already-preset; **KEEP**/out of scope.

Notes on SPECIAL: compact list-tile / pill actions and contextual-color (hero/ink/
danger) buttons do not map onto the full-width presets without a size/color variant.
They are deferred rather than forced, to avoid inventing a new variant this slice.

## F99 overall: still PARTIAL

All clean full-width and two-button-row CTAs are now on the presets (Slices 1 + 2).
What remains is exclusively:
- **KEEP** — genuine text links (`group_invite_page` copy / QR, `group_list` "New")
  and platform-dialog Cancel/OK actions (`friend_detail_sheet`, `group_detail_edit`,
  `expense_detail`, `setting` sign-out) — correct as TextButton, no work needed.
- **SPECIAL** — compact inline pills (`friend_add_row`, `friend_list`,
  `contact_suggestion_list`, `requested_friendship_list`, `group_detail_payment`),
  contextual-color hero/ink buttons (`group_detail` on-hero, `expense_detail` Scan),
  and the **P-danger** row in `settings_sheets`. These need a new compact-size and/or
  danger/contextual-color variant — a dedicated later slice, NOT built here.

F99 flips to FULLY done once the SPECIAL group is handled (after adding the
compact + danger variants). The KEEP set stays as TextButton by design.

## Live web sign-off: PENDING (browser harness unavailable).
