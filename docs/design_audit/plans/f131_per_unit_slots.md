# F131 — Claim page per-unit slot model (greenlit; supersedes F75)

Target: handoff "Tap to claim" item cards (`Deun Redesign v3.dc.html` §claim, ev:
`design_audit/screenshots/handoff_claim_screen_items.jpeg`). Today the claim page
renders one flat row per claim-unit entry with a single chip + split icon-button;
the prototype renders one card per *item* (qty N) with N per-unit slots.

## Data flow (mapped before UI work)

- `ClaimNotifier` loads the expense, subscribes `expense_update_checker`
  realtime, and mutates claimers via `ExpenseRepository.claimSetUnitShares`
  (server RPC — stays authoritative, no client fallback).
- Claim units = `expense_entry` rows with `split_mode='claim'`, `quantity=1`;
  same-item units share `item_group_id` (F146). Claimers = `expense_entry_share`
  rows; per-claimer cost = `unitCost / claimers.length`.
- F146's editor regrouping (`Expense.editorEntries`) groups by
  `item_group_id ?? id` — the same grouping the claim cards need, so the key
  loop is extracted and shared (`Expense.entriesByItem`).

## Slices

### Slice 1 — shared grouping (`Expense.entriesByItem`)
`Map<String, List<ExpenseEntry>>`, insertion-ordered; claim units key by
`itemGroupId ?? id`, pass-through entries by `id`. `editorEntries` refactored on
top of it (existing model tests keep it honest).

### Slice 2 — claim view model (`ClaimItemGroup`)
In `claim_math.dart`: name + unitCost + ordered `List<ClaimUnitRow>` units,
`quantity`, `firstFree`, `costForPersona`. `ClaimNotifier.itemGroups` maps
`entriesByItem` claim groups to it; `unitRows` becomes the flattened view.

### Slice 3 — item cards + interactions (claim_page.dart)
Per group one `SoftCard`:
- auto category icon tile (`CategoryDetector.detectCategory(name)` icon +
  `getColor` tint — theme palette, no prototype hex),
- name + `×N` (qty > 1), subline `€X.XX each · N ordered` (qty > 1) else the
  plain unit price,
- persona's cost for the item on the right when > 0,
- one chip per unit: solo → avatar + name; split → stacked avatars +
  `split · €each`; free → dashed `+ take one`,
- ghost `Split one` pill (dimmed/disabled when nothing free),
- right-hint `Tap a slot to take one` while free slots exist and the persona
  holds none.

Interactions (all through the existing notifier → server RPC):
- free chip tap → `claimUnit(entryId, persona)` (solo),
- claimed chip tap → split picker sheet for that unit (solo/split choice;
  unchecking yourself = unclaim via `splitUnit`),
- `Split one` → split picker on the first free unit, persona preselected.

l10n adds (en+de): `claimEachOrdered`, `claimTapSlotHint`.

### Slice 4 — tests + verification
Update `claim_chips_test` / `claim_page_test` to the card structure; add:
grouped card renders solo/split/free chips + `×N` + subline; free-slot tap
claims solo via the RPC path; claimed-chip tap and `Split one` open the modal;
`Split one` disabled when nothing free. Verify: analyze, full test run (clean
build on the known stale-artifact flake), Flutter web light+dark via Playwright
on the hans group with a throwaway itemized expense (removed after).

## Status

- [x] Slice 1–4 landed in one pass (this commit).

Out of scope (other findings): share-card polish F128–F130, CTA copy F132.
Skipped from the prototype: card tint when you hold units, "N yours" footer
badge — cosmetic extras beyond the finding's structure list; add if a later
finding names them.
