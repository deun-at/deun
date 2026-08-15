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

status: planned
