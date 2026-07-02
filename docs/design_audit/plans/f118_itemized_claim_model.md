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
- ~~Slice 3 (edit round-trip)~~ — DONE 2026-07-02 as F146, see below.

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

## Slice 3 (F146, 2026-07-02) — edit round-trip

Implemented:
- `Expense.editorEntries` (expense_model.dart): regroups per-unit claim
  entries by `item_group_id` into one synthetic qty-N entry (amount = group
  total, `unitClaims` = each unit's claimer emails in unit order); non-claim
  entries pass through; indices reassigned densely. `toJson()` now iterates
  editorEntries and emits the unit price, so form initial values line up
  with the regrouped cards.
- `ExpenseDetail.initState`: builds item cards from `editorEntries`, passes
  `initialName/initialAmount/initialQuantity` from the loaded entry (fixes
  the pre-existing €0.00 line-total/header seed — claim units have empty
  shares so the widget's shares-gated seeding never fired), and forces the
  itemized layout when the expense contains claim entries.
- `_saveExpense(claimable:true)`: injects `expense_entry[i][existing_claims]`
  from each regrouped entry's `unitClaims`; `saveAll` threads it into
  `explodeItemizedEntry`, which seeds unit i's shares from unitClaims[i]
  (percentage = 100 / claimers, same convention as claim_set_unit_shares).
  Positional: shrinking quantity drops trailing units' claims; new units
  start unclaimed. No RPC/migration change needed —
  `jsonb_populate_recordset` tolerates the email+percentage-only rows.

Verification (2026-07-02):
- `flutter analyze` clean; `flutter test` 753/753 green on a clean build
  (`flutter clean && flutter pub get`).
- Tests added: editorEntries regrouping/pass-through/standalone-unit +
  toJson seeding (expense_entry_claim_test.dart), explode-with-unitClaims
  preserve/grow/shrink (expense_repository_explode_test.dart), editor
  regroups to one qty-2 card + seeds "= €5.00" not €0.00
  (expense_itemized_editor_test.dart).
- Live (Flutter web + Playwright, hans group): created throwaway 2×€2.50
  itemized expense via the CTA → claimed one unit (Take one, Confirm) →
  Edit items showed ONE "2x = €5.00" card, header "Total from 1 item €5.00"
  → renamed item + re-saved via the CTA → claim survived (€2.50 of €5.00
  claimed by You, unit 2 still Take one) → deleted the expense; hans
  restored to its prior state (€877.74, original 4 expenses).
