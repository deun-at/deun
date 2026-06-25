# V3-T3b Report — Header migration batch A: 4 screens → DeunHeader

---

## V3-T3b FIX: DeunHeader robust centered title + trailingActions (edit+delete)

### Summary
Fixed `DeunHeader` to use a `Stack`-based layout for robust optical centering of the title regardless of trailing slot width, and added a `trailingActions: List<Widget>?` parameter. Removed the `OverflowBox` stop-gap from `expense_detail_read.dart`.

### Commands & output tails

#### flutter analyze
```
Analyzing deun...
No issues found! (ran in 9.1s)
```

#### flutter test test/widgets/deun_header_test.dart
```
00:01 +15: All tests passed!
```
15 tests (12 existing + 3 new trailingActions/centering tests), all green.

#### flutter test test/widgets/expense_detail_read_test.dart
```
00:01 +6: All tests passed!
```

#### flutter test (full suite)
```
00:35 +613 -6: Some tests failed.
```
613 pass (was 610 before this fix, +3 new), 6 failures are the same pre-existing ones.

#### grep -n OverflowBox lib/pages/expenses/presentation/expense_detail_read.dart
```
(no output — OverflowBox removed)
```

### Files changed

#### Production
- `lib/widgets/restyle/deun_header.dart` — Stack-based centering, `trailingActions` param
- `lib/pages/expenses/presentation/expense_detail_read.dart` — removed OverflowBox, use `trailingActions`

#### Tests
- `test/widgets/deun_header_test.dart` — 3 new tests added (TDD: written before implementation)

### Test counts
| Stage | Passed | Failed |
|-------|--------|--------|
| Before this fix | 610 | 6 |
| After this fix | 613 | 6 |
| New tests added | 3 | 0 |
| New failures | 0 | 0 |

---

## Commands & output tails

### flutter analyze
```
Analyzing deun...
No issues found! (ran in ~14s)
```

### flutter test (new tests only)
```
flutter test test/pages/groups/v3_header_migration_test.dart
00:07 +13: All tests passed!
```
13 new smoke tests, all green.

### flutter test (full suite)
```
00:49 +610 -6: Some tests failed.
```
- **Before migration**: +563 -6 (baseline)
- **After migration**: +610 -6 (added 13 new tests, 610 pass, same 6 pre-existing failures)
- **New failures introduced**: 0

### grep -n "AppBar" in migrated files
```
(no output — zero AppBar occurrences in all 4 files)
```

---

## Per-screen notes

### 1. `lib/pages/groups/presentation/group_detail_edit.dart`
- **Leading glyph**: `Icons.close` (modal-style form, new group or edit)
- **Title**: `l10n.groupCreateTitle` (new) / `l10n.groupEditTitle` (edit) — existing keys
- **Actions moved**: none (no AppBar actions in original)
- **Body change**: Removed `Scaffold.appBar`, added `DeunHeader` at top of body Column. Existing `SafeArea(top: false)` retained around inner body. Existing `_StickyFooter` unchanged.
- **Wrapper preserved**: `ThemeBuilder` outer wrapper intact.

### 2. `lib/pages/expenses/presentation/expense_detail.dart`
- **Leading glyph**: `Icons.close` (modal-style expense editor)
- **Title**: `l10n.expenseDetailTitle` — the only existing expense title l10n key. The original AppBar had **no title at all** (only `actions:`); `expenseDetailTitle` ("Expense") is used as the closest key without adding new strings.
- **Actions moved**: The original AppBar had a `FilledButton` save + optional `IconButton` delete. These do not fit cleanly in a 38×38 trailing slot:
  - **Delete icon** (`Icons.delete_outline`): moved to `trailing` as single `IconButton` (edit mode only).
  - **Save button** (`FilledButton`): moved to a pinned `Container` footer below the `Expanded(ListView)`, replacing the AppBar action. This is consistent with the `_StickyFooter` pattern used in `group_detail_edit.dart` and avoids visual overflow of a wide button in the 38px trailing slot. The itemized "Add & share for claiming" save button in the body is unchanged.
- **Concern**: The save button is now a footer rather than an AppBar action. Functionally equivalent but position changed. Noted here per brief instructions.
- **Wrapper preserved**: `ThemeBuilder` + `PopScope` (discard guard) intact.

### 3. `lib/pages/expenses/presentation/expense_detail_read.dart`
- **Leading glyph**: `Icons.arrow_back` (default)
- **Title**: `l10n.expenseDetailTitle` — same key as before
- **Actions moved**: Two icons (edit + delete) from AppBar `actions:` → `trailing: OverflowBox(child: Row(...))`. Two 38px-minimum `IconButton`s exceed the 38×38 trailing slot, so wrapped in `OverflowBox(maxWidth: double.infinity, alignment: Alignment.centerRight)` to allow them to paint outside the slot without a RenderFlex overflow error. Both icons are tap-accessible.
- **Concern (noted per brief)**: Multiple actions in trailing overflow the 38×38 box. Used `OverflowBox` as a stop-gap. The right long-term fix is a `DeunHeader` API extension (e.g. `trailingActions: List<Widget>`) that widens the trailing region when multiple actions are present — out of scope for this task.
- **Wrapper preserved**: `ThemeBuilder` intact.

### 4. `lib/pages/groups/presentation/group_join_page.dart`
- **Leading glyph**: `Icons.arrow_back` (default — drill-down)
- **Title**: `l10n.groupInviteJoinTitle` — existing key
- **Actions moved**: none (no AppBar actions)
- **Body change**: Removed `Scaffold.appBar` + `GoogleFonts.robotoSerif` title styling. Added `DeunHeader` + `Expanded(SafeArea(top:false, child: Center(...)))` wrapping the existing body content. The custom `GoogleFonts.robotoSerif` title style is intentionally dropped — DeunHeader uses its own Hanken typography per the v3 token spec; the `google_fonts` import was also removed.
- **No wrapper**: plain `StatefulWidget`, no `ThemeBuilder` here.

---

## Files changed

### Production
- `lib/pages/groups/presentation/group_detail_edit.dart`
- `lib/pages/expenses/presentation/expense_detail.dart`
- `lib/pages/expenses/presentation/expense_detail_read.dart`
- `lib/pages/groups/presentation/group_join_page.dart`

### Tests (new)
- `test/pages/groups/v3_header_migration_test.dart` — 13 smoke tests (TDD: written before production changes)

---

## Test counts
| Stage | Passed | Failed |
|-------|--------|--------|
| Baseline (before) | 563 | 6 |
| After migration | 610 | 6 |
| New tests added | 13 | 0 |
| New failures | 0 | 0 |

Pre-existing 6 failures (unchanged):
1. `claim_chips_test: Split one picker calls splitUnit with chosen members`
2. `expense_detail_tiles_test: tapping the date tile opens the date options sheet`
3. `expense_detail_tiles_test: "Pick a date…" in the date sheet opens the platform picker`
4. `expense_picker_sheets_test: PaidBySheet renders a row per member and pops the chosen email`
5. `group_edit_screen_test: shows Save button and the group name when editing`
6. `group_edit_screen_test: renders in dark mode without throwing`

---

## Concerns

1. **`expense_detail.dart` — save button position**: Moved from AppBar action to pinned footer. Functionally the same (always visible, same `_saveExpense` call), but vertically repositioned from top to bottom of screen. This is the standard pattern for full-screen forms in this app (`group_detail_edit.dart`), and avoids a wide `FilledButton` in a 38px trailing slot.

2. **`expense_detail_read.dart` — two-icon trailing via OverflowBox**: The `DeunHeader` wraps `trailing` in `SizedBox(38×38)`. Two `IconButton`s exceed this. Used `OverflowBox` to avoid the overflow error. Visually the icons protrude right of the nominal slot; they overlap the right edge of the header padding. Long-term fix: add a `trailingActions: List<Widget>?` convenience param to `DeunHeader` that skips the `SizedBox` wrap when multiple actions are present.

3. **`group_join_page.dart` — GoogleFonts removed**: The original title used `GoogleFonts.robotoSerif` (Roboto Serif w900). DeunHeader uses Hanken Grotesk w700 per v3 tokens. This is correct per the brief's instruction not to use custom styling in the header.

4. **`expense_detail.dart` — title key**: Original AppBar had no `title:`. Used `expenseDetailTitle` ("Expense") as the closest existing key. If a distinct "Edit expense" / "New expense" title is needed, a new l10n key should be added in a follow-up (separate from this task scope).
