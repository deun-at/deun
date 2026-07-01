# F118 — Itemized editor: replace per-item split UI with share-for-claiming model

Finding (greenlit, round 6): the itemized editor's per-item split UI (Amount/%/Parts
selector + member checkboxes with amount fields) does not exist in the handoff.
Items are simple cards that get SHARED FOR CLAIMING. Target: claim-only itemized
model — no per-item split section, info note "After you share, members claim their
own items — solo or split, per unit.", single CTA "Add & share for claiming".

## Current map (verified 2026-07-02)

- `expense_detail.dart` — editor. Quick vs Itemized via `resolveEditorMode`
  (entry count + `_itemizedOverride`). Itemized renders: total header, name,
  paid-by/date/category, item cards (`ExpenseEntryWidget` with
  `isSingleEntry:false`), "Add item by hand", info callout, inline CTA
  `_saveExpense(claimable:true)` — PLUS the pinned footer "Save"
  (`claimable:false`) which is always visible. That double-CTA divergence is
  BACKLOG I-5.
- `expense_entry_widget.dart` — item card. Always renders the split section
  (SectionLabel + 4-way `AppSegmentedControl<SplitMode>` + member checkbox rows
  + allocation bar) and registers form fields `shares`/`share_data`/
  `split_mode`/`locked_members`. In itemized mode this is the UI F118 removes.
- `claimable_form.dart` — `markEntriesClaimable` adds
  `expense_entry[i][claimable]=true` per index.
- `expense_repository.dart::saveAll` — reads `expenseEntry['shares']`
  (non-null assumption), adds them to `notificationReceiver`, then if
  `claimable==true` explodes the line via `explodeItemizedEntry` into per-unit
  `split_mode:'claim'` entries with empty shares (server RPC
  `save_expense_all` groups by `item_group_seq`). Claim page +
  `claim_set_unit_shares` RPC already handle claiming.

## Slice 1 (this session) — structural model change

1. `expense_entry_widget.dart`: render the split section ONLY when
   `isSingleEntry` (Quick keeps the full split UI, F105). Itemized item cards
   render name + amount/qty only and register no split form fields.
2. `expense_detail.dart`: itemized tab gets a single CTA — the inline
   "Add & share for claiming" (`claimable:true`), label no longer flips to
   "Save" when editing; the pinned footer Save is hidden in itemized mode
   (shown only in Quick). Resolves I-5; I-4's "toggle doesn't switch view"
   confusion goes away because the itemized view is now the claim-items view.
3. `claimable_form.dart`: `markEntriesClaimable` gains optional
   `notifyEmails` — writes `expense_entry[i][shares]` so the repository's
   existing notification wiring still notifies group members (they need to
   know there is something to claim). Editor passes all group member emails.
4. `expense_repository.dart`: tolerate absent `shares` key
   (`expenseEntry['shares'] ?? <String>{}`) since itemized cards no longer
   register it.
5. l10n: `itemizedInfoCallout` copy → "After you share, members claim their
   own items — solo or split, per unit." (en) + de equivalent; gen-l10n.
6. Tests: retarget `expense_entry_widget_test.dart` split-UI tests to Quick
   (`isSingleEntry:true`); add itemized-shows-no-split-UI tests; extend
   `expense_itemized_editor_test.dart` (no split selector/checkboxes in
   itemized, info note present, no footer Save in itemized);
   `mark_entries_claimable_test.dart` covers shares injection.

## Remaining slices (future sessions)

- Slice 2 (visual polish, tracked as F115–F117/F119/F120): unboxed total
  block, per-item auto icons + drop Category row, item-card layout ("€ X
  each", line total right, trash bottom-left, qty stepper bottom-right),
  dashed ghost "Add item by hand" button, CTA copy pass.
- Slice 3 (edit round-trip): when editing an already-shared claim expense,
  regroup per-unit claim entries by `item_group_id` into one qty-N card and
  preserve existing claims on re-save (today any edit-save re-explodes and
  wipes claimers — pre-existing behavior, unchanged by slice 1). Also
  pre-existing: claim units (empty shares) seed `_unitPrice` as 0 in
  `ExpenseEntryWidget.initState`, so the "= €X" line total and the itemized
  total header show €0.00 when editing a shared expense, even though the
  amount field itself round-trips correctly.

## Slice 1 verification (2026-07-02)

- `flutter analyze` clean; `flutter test` 744/744 green.
- Web (Playwright, 390×844, hans group, light + dark): itemized tab shows
  item cards only (no split selector, no member checkboxes), info note, and a
  single "Add & share for claiming" CTA; footer Save present in Quick only.
- End-to-end: created a throwaway 2×€2.50 itemized expense in hans via the
  CTA → group ledger showed "€5.00 · Tap to claim · €5.00 unclaimed", claim
  page showed two €2.50 units with Take one / Split one → deleted it; hans
  restored to its prior state.
- BACKLOG I-4/I-5 resolved by this slice (single claim-model view + single
  itemized save path).
