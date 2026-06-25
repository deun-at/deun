# V3-T10 Report — PrimaryButton (colored-shadow CTA) + migrate primary CTAs

## Status: DONE

## Commands run

```
# RED phase — verified test fails before implementation
flutter test test/widgets/primary_button_test.dart
→ FAIL (loading error: PrimaryButton not found — correct failure mode)

# GREEN phase — verified tests pass after implementation
flutter test test/widgets/primary_button_test.dart
→ 11/11 PASS

# Analyze (after const lint fixes in test file)
flutter analyze
→ No issues found!

# Full suite
flutter test
→ +684 -6 (684 pass, 6 fail — all 6 pre-existing, 0 new)
```

## Files changed

**New:**
- `lib/widgets/restyle/primary_button.dart` — PrimaryButton widget
- `test/widgets/primary_button_test.dart` — 11 TDD tests

**Production code migrations (9 files):**
- `lib/pages/auth/sign_in.dart`
- `lib/pages/auth/update_password.dart`
- `lib/pages/auth/onboarding_screen.dart`
- `lib/pages/groups/presentation/group_detail_edit.dart`
- `lib/pages/expenses/presentation/expense_detail.dart`
- `lib/pages/expenses/presentation/claim_page.dart`
- `lib/pages/groups/presentation/group_invite_page.dart`
- `lib/pages/groups/presentation/group_detail_payment.dart`
- `lib/widgets/restyle/expense_picker_sheets.dart`

**Test updates (1 file):**
- `test/pages/auth/login_screen_test.dart` — `FilledButton` → `PrimaryButton` finders for auth submit CTAs

## Converted vs. left button list

### CONVERTED to PrimaryButton

| File | Button | Reason |
|------|--------|--------|
| `sign_in.dart` | Sign in / Create account | Full-width form submit; THE primary CTA on the auth screen |
| `update_password.dart` | Update password | Full-width form submit; sole CTA on password-recovery screen |
| `onboarding_screen.dart` | Continue / Get started | Full-width primary action; onboarding flow CTA |
| `group_detail_edit.dart` `_StickyFooter` | Create / Save | Full-width sticky footer; primary group form submit |
| `expense_detail.dart` footer | Save | Full-width pinned footer; primary expense save CTA |
| `expense_detail.dart` itemized | Save and share for claiming | Full-width; primary itemized-save/claim CTA |
| `claim_page.dart` `_ClaimBar` | Confirm (€X.XX) | Full-width sticky confirm bar; primary claim CTA |
| `claim_page.dart` `_SplitPickerSheet` footer | Apply | Full-width SheetScaffold footer; primary split-picker confirm |
| `claim_page.dart` `_ClaimSuccessSheet` footer | Done | Full-width SheetScaffold footer; primary success dismiss CTA |
| `group_invite_page.dart` footer | Share (with icon) | Full-width SheetScaffold footer; primary share action |
| `group_detail_payment.dart` `_MethodDetailSheet` footer | Pay €X.XX | Full-width SheetScaffold footer; primary payment confirm CTA |
| `expense_picker_sheets.dart` keypad | Save (keypad confirm) | Full-width SheetScaffold footer; primary keypad entry confirm |

### LEFT as FilledButton (not converted)

| File | Button | Reason |
|------|--------|--------|
| `discard_sheet.dart` | Discard changes | Destructive; uses `colorScheme.error` — must stay danger-colored |
| `expense_detail_read.dart` | Delete expense (dialog) | Destructive dialog action; error color; compact (in AlertDialog actions) |
| `expense_detail.dart` | Delete expense (dialog) | Same as above |
| `group_detail_edit.dart` line 180 | Delete group (dialog) | Destructive dialog action; error color; compact |
| `setting.dart` | Sign out (dialog) | Destructive dialog action; error color; compact |
| `settings_sheets.dart` | Delete account (confirm) | Destructive; error color; in a Row with Cancel (not full-width standalone) |
| `friend_accept_page.dart` line 124 | Close (error state) | Small error-state recovery button; not the happy-path CTA |
| `friend_accept_page.dart` line 175 | Accept | In a `Row` with a Cancel `OutlinedButton` — not a standalone full-width CTA |
| `contact.dart` | Send | `Align(centerRight)` — not full-width |
| `settings_profile_form.dart` | Update | `Align(centerRight)` — not full-width |
| `friend_add_row.dart` | Add | Small list-row chip |
| `requested_friendship_list.dart` | Accept / Decline chips | Small list-row chips |
| `pending_request_list.dart` | Cancel chip | Small list-row chip |
| `contact_suggestion_list.dart` | Add | FilledButton.tonal chip |
| `friend_list.dart` line 282 | Accept (in card Row) | In a card Row with icon button; not full-width |
| `friend_detail_sheet.dart` | Remove friend (dialog) | Destructive dialog; error color |
| `friend_qr_page.dart` | Copy link / Share (Row pair) | Two equal-width buttons in a Row; neither is the sole primary CTA |
| `friend_qr_page.dart` line 532 | FilledButton.tonal | Tonal (secondary) action |
| `group_detail.dart` | Settle Up | Custom-colored (onHero/heroSurface); FAB-area design element, not §1 CTA |
| `group_join_page.dart` | Join group | Medium icon button; not a standalone full-width primary |
| `group_detail_payment.dart` line 200 | Pay (list-row) | `FilledButton.icon` in a list-row card; not the primary footer CTA |
| `receipt_scanner_sheet.dart` line 161 | Take photo | One of two competing options (camera vs gallery); neither is the sole CTA |
| `receipt_scanner_sheet.dart` line 168 | Choose from gallery | `FilledButton.tonalIcon` — secondary option |
| `receipt_scanner_sheet.dart` line 444 | Use items (confirm) | Part of a `Row` with a Retake tonal button — 2/3 width, not standalone full-width |

## Dark-shadow choice

In dark mode: shadow alpha reduced from `0.5` → `0.25`. Rationale: a fully-saturated purple drop-shadow (`rgba(87,80,230,0.5)`) reads as colored glow on near-black `#121311` surfaces rather than depth. At `0.25` it provides subtle lift without the halo effect. Shadow is still present (not omitted) to preserve the design gesture in dark mode.

## Test counts

- `primary_button_test.dart`: **11/11 pass**
- `login_screen_test.dart`: **all pass** (finders updated FilledButton → PrimaryButton for auth CTAs)
- `group_edit_screen_test.dart`: **3/5 pass**, 2 pre-existing failures (ListTile-in-DecoratedBox assertion from SoftCard — existed before this task)
- `group_detail_payment_test.dart`: **all pass** (list-row Pay button finders correctly kept as FilledButton)
- `discard_sheet_test.dart`: **all pass** (not converted — still uses FilledButton with error color)
- `claim_page_test.dart`: **all pass**
- `group_invite_page_test.dart`: **all pass**

**Full suite: 684 pass / 6 fail — 0 new failures introduced.**

The 6 failures are pre-existing:
1. `claim_chips_test.dart: Split one picker calls splitUnit with chosen members`
2. `expense_detail_tiles_test.dart: "Pick a date…" in the date sheet opens the platform picker`
3. `expense_detail_tiles_test.dart: tapping the date tile opens the date options sheet`
4. `expense_picker_sheets_test.dart: PaidBySheet renders a row per member and pops the chosen email`
5. `group_edit_screen_test.dart: shows Save button and the group name when editing`
6. `group_edit_screen_test.dart: renders in dark mode without throwing`

## Concerns

None. The `loading` param on `PrimaryButton` cleanly replaces the inline `_isLoading ? spinner : Text(label)` pattern from all converted screens (sign_in, update_password, onboarding) — behavior is identical. All conversions are faithful swaps: same `onPressed`, same label/l10n key, same enabled/disabled logic.
