# group-form-field-structure — Group edit form: fields in a Column, not a lazy ListView

## Spec
- Source: idea (fallout from the multi-currency-foundation regression, 2026-07-12)
- Flight: —
- Goal: Make the group edit form structurally incapable of losing a field value on scroll, matching the expense form's proven pattern.
- Acceptance:
  - The group edit form's fields (name/color, members, tracking mode, currency, edit-only actions) render inside a single `Column` that is the child of `FormBuilder`, with one outer scroller wrapping the whole form — i.e. no `FormBuilder`-owned field is a direct child of a lazily-built scrollable.
  - Scrolling to the currency picker at the bottom and then saving preserves the group name and every other field value (no field is disposed/unregistered by scrolling).
  - `clearValueOnUnregister` on this form matches the expense form's setting (`true`), since the structural change removes the need for the `false` stopgap.
  - No visual or layout regression on both create (new group) and edit (existing group) flows: same section order, spacing, sticky footer, and edit-only actions block.
  - Existing group-edit widget/model tests pass, plus a test proving a scrolled-off name field retains its value through save.

## Approach
- Mirror `expense_detail.dart`: outer `ListView` (or equivalent single scroller) → `FormBuilder` → `Column(mainAxisSize: min)` holding the field widgets, rather than the current `FormBuilder` → `ListView(fields as direct children)`. Fields inside a `Column` are always mounted, so they never unregister on scroll and `clearValueOnUnregister: true` only clears genuinely-removed conditional fields (correct behaviour), consistent with the expense form and the settings forms.
- Fold the current stopgap (`clearValueOnUnregister: false`) back to `true` as part of the restructure — the two changes are one unit; don't leave both behaviours in the tree.
- Likely touchpoints: lib/pages/groups/presentation/group_detail_edit.dart (form structure only). Cross-reference lib/pages/expenses/presentation/expense_detail.dart for the canonical pattern. Watch the sticky footer / `Expanded` wrapping and the edit-only actions spread so scroll and layout stay identical.
- Decisions / tradeoffs: Pure structural refactor — no behaviour change beyond field-retention. The alternative (leaving `clearValueOnUnregister: false`) already prevents the data loss but keeps this form as the one inconsistent exception; this feature exists to remove that inconsistency, not to re-fix the bug.
- Depends: —
- Parallel-with: —
- Blockers: —

status: done

## Evidence

Implementation matched the Approach exactly: `lib/pages/groups/presentation/group_detail_edit.dart`'s
`Expanded(child: SafeArea(...))` now wraps a single outer `ListView` whose only child is the
`FormBuilder`; the `FormBuilder`'s child is a `Column(mainAxisSize: min, crossAxisAlignment: stretch)`
holding all five field widgets plus the edit-only actions block, in the original order. `stretch`
(rather than the expense form's `.start`) was required to keep the tight full-width constraint the
swatch row, `SectionLabel` and `_TrackingModeField`'s side-by-side cards depend on.
`clearValueOnUnregister` flipped from `false` to `true` in the same change, and the two stale comments
(the `false`-justification block and `_TrackingModeField`'s "unbounded height inside the ListView"
note) were rewritten to describe the new structure.

Criterion-by-criterion, proven by `test/widgets/group_edit_screen_test.dart` (5 new `testWidgets`,
red before the restructure — asserting `Column`/no-`SliverList`/off-viewport-mounted facts that only
hold once fields stop being direct `ListView` children — green after; 2 pre-existing tests had their
comments refreshed only, assertions untouched):

- "Fields in a single `Column` child of `FormBuilder`, one outer scroller, no field inside a
  lazily-built scrollable" — `every form field renders in a single Column under the FormBuilder,
  wrapped by one outer scroller`: asserts exactly one `ListView` that is an *ancestor* of
  `FormBuilder` (not the reverse), no `SliverList` descendant of `FormBuilder`, the `FormBuilder.child`
  is a `Column` with `mainAxisSize: min` / `crossAxisAlignment: stretch`, and all five fields already
  built on a 400x400 viewport with zero scrolling.
- "`clearValueOnUnregister` matches the expense form (`true`)" — `clearValueOnUnregister matches the
  expense form (true), the false stopgap is gone`.
- "Scrolling to the currency picker and saving preserves the name and every other field value" —
  `scrolling to the currency picker keeps the name field mounted and its value survives save (create)`
  (name field stays mounted off-viewport; `saveAndValidate()` + `form.value['name']` survive the
  scroll) and `scrolling to the bottom preserves every other field value too (edit)` (`color_value`,
  `simplified_expenses`, `currency_code`, `group_members` all survive).
- "No visual/layout regression on create and edit" — `no layout regression: section order, full-width
  fields and sticky footer (create and edit)`: 760px full content width on an 800px viewport, section
  order preserved top-to-bottom on both flows (incl. the edit-only invite/delete block), sticky footer
  stays outside and below the scroller, no exceptions thrown.
- "Existing group-edit widget/model tests pass" — all 14 pre-existing `testWidgets` in the same file
  pass unmodified (only 2 stale comments refreshed).

Gate summary (Flutter SDK at `C:\Users\ASUS\flutter\bin`, per `project_flutter_deviceguard_workaround`):
- format: `dart format --output=none --set-exit-if-changed` on both touched files — "Formatted 2 files
  (0 changed)".
- lint: `flutter analyze` — "No issues found! (ran in 14.6s)".
- test (targeted): `flutter test test/widgets/group_edit_screen_test.dart` — "+18: All tests passed!"
  (14 pre-existing + 5 new, incl. `every form field renders in a single Column under the FormBuilder,
  wrapped by one outer scroller`, `clearValueOnUnregister matches the expense form (true), the false
  stopgap is gone`, `scrolling to the currency picker keeps the name field mounted and its value
  survives save (create)`, `scrolling to the bottom preserves every other field value too (edit)`,
  `no layout regression: section order, full-width fields and sticky footer (create and edit)`).
- test (full suite): `flutter test` — "+958: All tests passed!" (0 regressions elsewhere).

Review verdict: round 1 found 2 lean findings — both in the new test file, redundant/imprecise finders
(a `find.byType(TextFormField)` that should have targeted the named field by hint text, and a
duplicate `clearValueOnUnregister` re-assertion inside the save-survival test) — both fixed by scoping
the finder to the actual name field via `find.widgetWithText(TextFormField, l10n.groupNameHint)` and
dropping the redundant assertion. Round 2: `review: clean`.
