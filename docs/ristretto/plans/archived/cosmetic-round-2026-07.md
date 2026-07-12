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

status: done

## Evidence

Each acceptance bullet was transcribed into a widget test that restates it; the
full suite is green. Gate summary (`.ristretto.json`, toolchain
`C:\Users\ASUS\flutter\bin`): `dart format` → 12 touched files, 0 changed;
`flutter analyze` → No issues found!; `flutter test` → 922 passing.

- **Add-friends shimmer padding.** Added `ShimmerCardList.horizontalPadding`
  (default 16, threaded to the skeletons' clip-safe inset). The two add-friends
  sections (`search_result_list.dart`, `contact_suggestion_list.dart`) already
  sit inside a 20px page padding, so they now pass `horizontalPadding: 0` — the
  skeleton lines up with the loaded `SoftCard` instead of sitting 16px further
  in and jumping on load. Proof: `shimmer_card_list_test.dart` →
  *"horizontalPadding controls the skeleton inset (default 16, override 0)"*
  (SoftCard left = 16 by default, 0 when overridden).
- **Long group name never underlaps the search button.** `deun_header.dart` now
  reserves a symmetric title inset equal to the widest slot
  (`trailingActionCount × 48dp`) instead of a fixed 46px that only cleared one
  action, so a centered title truncates before reaching a multi-action trailing
  Row. Proof: `deun_header_test.dart` → *"long title never paints under the
  trailing actions"* (title right edge ≤ first trailing action left edge); the
  existing full-width centering test stays green.
- **Expense read "you owe / you get back" right-aligned.** `_PaidNetRow` in
  `expense_detail_read.dart` changed `Flexible(payer) + Spacer()` → `Expanded`.
  The old pair split the free space 50/50, parking the leftover slack to the
  *right* of the net label so it was not flush-right. Proof:
  `expense_detail_read_test.dart` → *"summary net line is right-aligned to the
  card content edge"* (net right ≈ card right − 18px padding; net left > payer
  right).
- **Statistics card in landscape correctly aligned.** Verified the big summary
  card is already responsive (full-flex content on the 16px grid); no code
  change was warranted — the reported layout holds in landscape. Proof:
  `stats_summary_landscape_test.dart` → renders at 900×400 with no overflow
  exception (*not clipped*) and the card's edges sit at 16 / width−16 (*on the
  content grid, not off-grid*).
- **Itemized "Add & share for claiming" CTA pinned to the bottom.**
  `expense_detail.dart` moves the CTA out of the scrolling `ListView` into the
  shared opaque `surface`-colored footer bar (now used by both Quick and
  Itemized); because the footer is a Column sibling (not an overlay) the list is
  never hidden behind it, and the list's bottom inset no longer needs to clear an
  in-list CTA. Proof: `expense_itemized_editor_test.dart` → *"itemized CTA is
  pinned in the footer, not a scroll child"* (CTA is not a `ListView`
  descendant; sits on a `surface`-colored `Container` below the list).
- **Itemized paid-by / when as one connected block.** The itemized layout now
  uses the same `_buildPaidWhenList()` as Quick — a single card with the hairline
  connecting divider — instead of two separate spaced `SoftCard`s. Proof:
  `expense_itemized_editor_test.dart` → *"itemized Paid-by and When are one
  connected card with a divider"* (both rows share one `SoftCard` ancestor which
  contains a `Divider`).
- **Quick-split section on the grid.** `expense_entry_widget.dart` single-entry
  padding end changed 8 → 16 (symmetric 16), matching the other form sections.
  Proof: `expense_itemized_editor_test.dart` → *"quick split section aligns to
  the 16px content grid"* (entry padding left = 16, right = 16).
