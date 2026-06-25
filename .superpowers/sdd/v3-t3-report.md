# V3-T3 Report: DeunHeader custom header widget + personal stats migration

## Commands & Output

### flutter analyze
```
Analyzing deun...
No issues found! (ran in 15.9s)
```

### flutter test test/widgets/deun_header_test.dart
```
00:01 +12: All tests passed!
```
12 tests, all green.

### flutter test (full suite)
```
00:42 +597 -6: Some tests failed.

Failing tests:
  C:/work/deun/test/widgets/claim_chips_test.dart: Split one picker calls splitUnit with chosen members
  C:/work/deun/test/widgets/expense_detail_tiles_test.dart: "Pick a date…" in the date sheet opens the platform picker
  C:/work/deun/test/widgets/expense_detail_tiles_test.dart: tapping the date tile opens the date options sheet
  C:/work/deun/test/widgets/expense_picker_sheets_test.dart: PaidBySheet renders a row per member and pops the chosen email
  ... and 2 more
```
597 pass, same 6 pre-existing failures. 0 new failures.

## TDD Cycle Followed

1. **RED**: Wrote `test/widgets/deun_header_test.dart` (12 tests covering all required behaviors) before any production code. Verified failure: compile error `Error when reading 'lib/widgets/restyle/deun_header.dart': Das System kann die angegebene Datei nicht finden`.
2. **GREEN**: Implemented `lib/widgets/restyle/deun_header.dart` (and fixed a duplicate-field bug caught immediately by the test run). All 12 tests passed.
3. **REFACTOR**: No structural changes needed; code was clean on first pass.

## Files Changed

- **Created**: `lib/widgets/restyle/deun_header.dart` — `DeunHeader` widget + internal `_HeaderIconButton`
- **Created**: `test/widgets/deun_header_test.dart` — 12 widget tests covering all spec behaviors
- **Modified**: `lib/pages/statistics/personal_statistics_page.dart` — removed `appBar: AppBar(...)`, replaced with `DeunHeader` at top of `Column` body; wrapped existing scroll content in `Expanded` + `SafeArea(top: false)`

## Light/Dark Token-Mapping Reasoning

| Token | Light result | Dark result | Why correct |
|---|---|---|---|
| `colorScheme.onSurface.withValues(alpha: 0.04)` (circle bg) | faint warm dark tint on white/cream bg | faint light tint on dark bg | onSurface flips with brightness; 4% opacity gives the same perceptual weight in both modes |
| `colorScheme.onSurface` (icon color, title color) | near-black `#16181A` equivalent | near-white equivalent | M3 semantic token, auto-flips |
| `colorScheme.onSurfaceVariant` (subtitle color) | muted grey | muted light grey | Correct subdued treatment in both modes |
| Header background | transparent (inherits Scaffold background) | transparent (inherits dark Scaffold bg) | No hard-coded color; sits naturally on whatever screen bg is used |
| `textTheme.bodyLarge` (16px Hanken) + w700 | ✓ correct font + weight | ✓ same font + weight | Font family from ThemeData, not hard-coded |
| `textTheme.bodySmall` (≈11.5px) for subtitle | ✓ | ✓ | Same token |

No hex values were hard-coded in the widget.

## Geometry

All geometry values are layout constants (literals per spec):
- Row height driven by 38px buttons + 4px/8px vertical padding
- `SafeArea(bottom: false)` handles status-bar inset
- `_HeaderIconButton`: 38px visible circle, 48px hit target via `EdgeInsets.all(5)` padding on the `InkWell`
- `InkWell(customBorder: CircleBorder())` → circular ripple, no M3 square ripple

## Migration Notes (personal_statistics_page.dart)

- Removed `appBar: AppBar(title: Text(l10n.statisticsPersonalOverviewTitle))`
- Body is now `Column([DeunHeader(title: ...), Expanded(SafeArea(top: false, child: SingleChildScrollView(...)))])`
- `SafeArea(top: false)` on the body: the `DeunHeader` already handles top SafeArea internally via `SafeArea(bottom: false)`, so the body doesn't double-pad
- All existing body content (AppSegmentedControl, state.when loading/error/data, PersonalSummarySection, PersonalTrendSection, PersonalGroupsSection) is preserved unchanged
- Back navigation: default `onLeading` calls `Navigator.of(context).maybePop()` which works correctly with go_router

## Concerns

None. All verification gates passed:
- `flutter analyze` clean
- `flutter test test/widgets/deun_header_test.dart` → 12/12 green
- Full `flutter test` → 597 pass, same 6 pre-existing failures (no new failures)
