# cosmetic-round-2026-07 — Post-release alignment & polish round

## Spec
- Source: idea (user-reported visual issues, 2026-07-12 planning session)
- Flight: —
- Goal: Fix seven small visual defects reported after the v2.0.0 release; each is a binary visual check against the design handoff.
- Acceptance:
  - Add-friends screen: the loading shimmer uses the same padding as the loaded list content (no offset jump when content arrives).
  - Group detail: a long group name never overlaps or paints under the search button — it truncates/ellipsizes before reaching it.
  - Expense detail read view: the "you owe / you get back" line is right-aligned; the current fixed left spacing is removed.
  - Group detail statistics card: opening the screen in landscape shows the big statistics card correctly aligned (no clipped or off-grid layout).
  - Itemized editor: the "Add & share for claiming" CTA is fixed to the bottom of the screen on an opaque surface-colored bar (per design handoff), instead of scrolling with the content; list content is not hidden behind it (bottom inset respected).
  - Itemized editor: the "paid by" and "when" fields render as one connected block with the small connecting border, identical in style to the quick-split layout.
  - Quick-split editor: the split section aligns to the same grid as the other form sections (no stray horizontal offset).
  - `flutter analyze` and `flutter test` pass; existing golden/widget tests updated where layout legitimately changed.
## Approach
- Pure presentation-layer round — no data or provider changes. Verify each fix against docs/design_handoff/ (DESIGN_SPEC.md, COMPONENTS.md) rather than eyeballing; the CTA-bar and connected-field patterns are specified there.
- Likely touchpoints: lib/pages/friends/presentation/ (shimmer), lib/pages/groups/presentation/group_detail.dart (heading/search, stats card), lib/pages/expenses/presentation/expense_detail_read.dart ("you owe" alignment), lib/pages/expenses/presentation/expense_detail.dart (CTA bar, paid-by/when block, split section), lib/widgets/shimmer_card_list.dart.
- Decisions / tradeoffs: one round, one branch — these are too small to track individually, but each acceptance bullet is independently verifiable so partial completion is visible.
- Depends: —
- Parallel-with: tab-switch-transition
- Blockers: —

status: planned
