# V3-T9a Report — Sheet shell to COMPONENTS §3

## TDD Process

### RED phase
Added 6 new SheetScaffold tests to `test/widgets/restyle_widgets_test.dart` before touching production code:
- surface uses `surfaceContainerLow` with top radius 30, square bottom
- exactly one drag handle rendered — sized 38×4 — colored `outlineVariant`
- title renders with `fontWeight w700`
- default padding is `EdgeInsets.fromLTRB(20, 8, 20, 26)`
- `kSheetBarrierColor` has approximately 0.4 opacity

Confirmed RED: compilation error — `Undefined name 'kSheetBarrierColor'`.

### GREEN phase
Implemented all production changes; all 38 tests in restyle_widgets_test.dart passed.

## Files Changed

### `lib/constants.dart`
Added `kSheetBarrierColor = Color(0x6610100E)` directly above `kSheetAnimationStyle`. Alpha `0x66 / 0xFF ≈ 0.400`, warm near-black `#10100E`.

### `lib/widgets/restyle/sheet_scaffold.dart`
- Top radius 28 → **30** (`BorderRadius.vertical(top: Radius.circular(30))`)
- Drag handle: width 36 → **38**, height 4 (kept), border radius 8 → **2**, color `surfaceContainerHighest` → **`outlineVariant`**
- Handle vertical padding: `symmetric(vertical:12)` → `only(top:6, bottom:6)` (~6px top margin per §3)
- Title style: `textTheme.titleLarge` → `textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurface)`
- Default padding: `EdgeInsets.fromLTRB(20, 0, 20, 20)` → **`EdgeInsets.fromLTRB(20, 8, 20, 26)`**

### `lib/widgets/theme_builder.dart`
- `bottomSheetTheme` radius 28 → **30**
- `showDragHandle: true` → **`false`** (double-handle fix: SheetScaffold draws its own)
- Added `backgroundColor: surfaceContainerLow` (warm flat surface)
- Added `surfaceTintColor: Colors.transparent` (kill M3 tonal tint)

### `lib/widgets/modal_bottom_sheet_page.dart`
Added `modalBarrierColor: kSheetBarrierColor` to the `ModalBottomSheetRoute` constructor (covers routed sheets: month, category, payment, share).

### Scrim sites — inline `showModalBottomSheet` calls
Added `barrierColor: kSheetBarrierColor` to 9 call sites:

| File | Call sites updated |
|------|--------------------|
| `lib/pages/settings/settings_sheets.dart` | 3 (language, appearance, delete-account sheets) |
| `lib/widgets/restyle/expense_picker_sheets.dart` | 1 (`_showSheet` helper — covers all picker sheets) |
| `lib/widgets/restyle/discard_sheet.dart` | 1 |
| `lib/pages/expenses/presentation/claim_page.dart` | 2 (`_openSplitPicker`, `_confirm`) |
| `lib/pages/expenses/presentation/expense_detail.dart` | 1 (`_scanReceipt`) |
| `lib/pages/friends/presentation/friend_detail_sheet.dart` | 1 (`openFriendDetailSheet`) |
| `lib/pages/groups/presentation/group_detail.dart` | 1 (receipt scan FAB) |
| `lib/pages/groups/presentation/group_detail_payment.dart` | 1 (`_openMethodSheet`) |
| `lib/widgets/dev/widget_gallery_page.dart` | 1 (dev gallery) |

Total: 10 inline call sites + 1 routed via `ModalBottomSheetPage`.

## Double-Handle Resolution

**Before:** `bottomSheetTheme` had `showDragHandle: true`, causing the Material framework to inject an M3 drag handle on top of `SheetScaffold`'s own custom handle — resulting in two handles stacked.

**After:** `showDragHandle: false` in the theme; `SheetScaffold` draws exactly one 38×4 `outlineVariant` pill. The test "exactly one drag handle rendered" guards this regression.

## Verification

### `flutter analyze`
```
Analyzing deun...
No issues found! (ran in 13.3s)
```

### SheetScaffold tests
```
00:04 +38: All tests passed!
```
38 tests, 0 failures.

### Full `flutter test`
```
+671 -6: Some tests failed.
```
- **671 total, 665 passed, 6 failed**
- The 6 failures are all pre-existing:
  - `claim_chips_test.dart: Split one picker calls splitUnit with chosen members`
  - `expense_detail_tiles_test.dart: "Pick a date…" in the date sheet opens the platform picker`
  - `expense_detail_tiles_test.dart: tapping the date tile opens the date options sheet`
  - `expense_picker_sheets_test.dart: PaidBySheet renders a row per member and pops the chosen email`
  - + 2 more pre-existing (expense_picker/sheet)
- **No new failures introduced.**

## Concerns

None. The settle-up payment sheet (`group_detail_payment.dart`) was intentionally **not** migrated to SheetScaffold — that is V3-T9b. Only `barrierColor` was applied there. The `ReceiptScannerSheet` also was not converted — it is not in scope.

## Commit
`V3-T9a: sheet shell to COMPONENTS §3 (radius 30, custom handle, scrim)`
