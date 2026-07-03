# F143 · Standardize on TWO list presets — Implementation Plan

> **For agentic workers:** presentation-only refactor. Data, queries, providers, routes, keys, ordering UNCHANGED. Colors via theme/SemanticColors. No copy changes.

**Goal:** Every vertical card/row list in `lib/pages` uses exactly ONE of two SHARED presets: a SPACED card list (gaps between cards) or a NON-SPACED joined-row list (one card, hairline-joined rows).

**The inconsistency F143 names:** the NON-SPACED preset already exists as a shared widget (`CardColumn` in `card_list_view_builder.dart`), but the SPACED list is done ad-hoc everywhere (manual `Padding(...) + SoftCard`) with *different gap values* — `group_list` uses `Padding(vertical:5)` (10px gap), `friend_list` uses `Padding(bottom:8)` (8px gap). No shared spaced preset. That's the fix: introduce ONE shared `SpacedCardList`/spaced-item widget and route the ad-hoc spaced lists through it.

---

## Inventory (STEP 1)

| # | Screen / file | Current impl | Preset it should be | Matches? |
|---|---------------|--------------|--------------------|----------|
| 1 | Group list — `pages/groups/presentation/group_list.dart` + `group_list_item.dart` | `Padding(vertical:5)` + `SoftCard` per item, ad-hoc | **SPACED** | ad-hoc gap |
| 2 | Friends screen requests (incoming) — `friend_list.dart` `_IncomingRequestCard` | `Padding(bottom:8)` + `SoftCard` | **SPACED** | ad-hoc gap |
| 3 | Friends screen requests (outgoing) — `friend_list.dart` `_OutgoingRequestCard` | `Padding(bottom:8)` + `SoftCard` | **SPACED** | ad-hoc gap |
| 4 | Friends screen all-friends — `friend_list.dart` `_FriendCard` | **`CardColumn` (joined rows)** ✓ | **NON-SPACED** | ✓ fixed (slice 2) |
| 5 | Settings preferences — `pages/settings/setting.dart` `_buildSettingsList` | `SoftCard(padding:0)` + `Column` + `_SettingsRow` + `_RowDivider` | **NON-SPACED** | joined, but own divider pattern (not `CardColumn`) |
| 6 | Group-detail date groups — `group_detail_list.dart` (F138) | `SoftCard` + inner `Column` of rows | **NON-SPACED** | joined ✓ (already correct — DO NOT REGRESS) |
| 7 | Expense-detail member breakdown — `expense_detail.dart` (F122) | `CardColumn` | **NON-SPACED** | joined ✓ shared (already correct) |
| 8 | Friend-add page sub-lists — `pending_request_list.dart`, `requested_friendship_list.dart` | `CardColumn` | **NON-SPACED** | joined ✓ shared |

**Note on #4 (all-friends):** DONE in slice 2. Converted from the SPACED preset (per-card `SoftCard` via `spacedCardItems`) to the shared NON-SPACED `CardColumn` — one card, rows joined, no inter-row gap, matching v3 "All friends" (`border-radius:22`, joined rows, hairline joins, chevron per row). `_FriendCard` dropped its `SoftCard` wrapper and became an ink-splashing `InkWell + Padding(16)` row (CardColumn's `CardListTile` now provides the card surface). Content/tap/keys/ordering/balance layout (F95/F07/F06) unchanged.

## STEP 2 — shared presets

- **NON-SPACED:** already shared → `CardColumn` (`lib/widgets/card_list_view_builder.dart`). Keep. F138 & settings use their own ad-hoc joined variants; those can later route through `CardColumn`, but F138/settings joined lists are visually correct today so not urgent for this slice.
- **SPACED:** create ONE shared widget `SpacedCardList` in `lib/widgets/restyle/spaced_card_list.dart`. It maps a list of item widgets to a `Column`/`ListView` of `SoftCard`s separated by a consistent gap (default 10, the group-list value — the dominant spaced list). Keeps SoftCard radius/shadow tokens. Small, mirrors `CardColumn`.

## STEP 3 — slice applied THIS iteration

**DONE:**
- Create `SpacedCardList` (+ `spacedCardChildren` helper for the friend-list stagger case, which needs the spaced items as a flat `List<Widget>` to interleave with section labels).
- Route **group list** (#1) through the shared spaced gap.
- Route **friends screen requests** (#2, #3) through the shared spaced gap.

## STEP 4 — slice 2 (final slice)

**DONE:**
- #4 all-friends → converted to the shared NON-SPACED `CardColumn` (see note above). New `friend_list_test.dart` cases assert: all-friends renders one `CardColumn` with joined rows (bottom of one row card flush against the top of the next, no gap) and NO per-row `SoftCard`; the request sections still render per-card `SoftCard`s (SPACED preset).

**Deliberately left on a local equivalent (NON-SPACED, visually correct, NOT routed through `CardColumn`):**
- **#5 Settings preferences** (`setting.dart` `_buildSettingsList`) — one `SoftCard(padding:0)` + `Column` of `_SettingsRow`s separated by `_RowDivider` **hairline dividers**. This matches v3 Settings exactly (`border-bottom:1px solid rgba(20,18,12,0.05)` between rows). `CardColumn` joins rows with rounded-corner per-`Card` tiles and NO hairline divider, so routing settings through it would DROP the v3 hairlines — a visual regression. Kept as the correct local non-spaced pattern.
- **#6 Group-detail date groups** (`group_detail_list.dart` `_DaySection`, F138) — one `SoftCard(borderRadius:20, padding:vertical 4)` + inner `Column` of ledger rows, with the payback row as an inset floating chip. `CardColumn` hardcodes radius 28/8 and per-row `Card` surfaces, which would change the single-card radius and the payback chip's inset — a distinct visual + F138 test risk. Kept; visually correct today.

**Already shared NON-SPACED (no work):**
- #7 Expense-detail breakdown (`expense_detail.dart`, F122) already uses `CardColumn`.
- #8 Friend-add sub-lists already use `CardColumn`.

**Status: F143 COMPLETE.** Exactly two shared presets in use: SPACED (`SpacedCardList`/`spacedCardItems`) on group list + friend requests/pending; NON-SPACED (`CardColumn`) on all-friends, expense-detail breakdown, and friend-add sub-lists. Settings + F138 group-detail keep their own visually-correct non-spaced patterns (hairline-divider list / single-card date group) that `CardColumn` cannot reproduce without regressing v3 fidelity — documented above.
