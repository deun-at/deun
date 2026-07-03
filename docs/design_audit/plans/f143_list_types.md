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
| 4 | Friends screen all-friends — `friend_list.dart` `_FriendCard` | `Padding(bottom:8)` + `SoftCard` | **NON-SPACED** (per goal) *see note* | ad-hoc / wrong type |
| 5 | Settings preferences — `pages/settings/setting.dart` `_buildSettingsList` | `SoftCard(padding:0)` + `Column` + `_SettingsRow` + `_RowDivider` | **NON-SPACED** | joined, but own divider pattern (not `CardColumn`) |
| 6 | Group-detail date groups — `group_detail_list.dart` (F138) | `SoftCard` + inner `Column` of rows | **NON-SPACED** | joined ✓ (already correct — DO NOT REGRESS) |
| 7 | Expense-detail member breakdown — `expense_detail.dart` (F122) | `CardColumn` | **NON-SPACED** | joined ✓ shared (already correct) |
| 8 | Friend-add page sub-lists — `pending_request_list.dart`, `requested_friendship_list.dart` | `CardColumn` | **NON-SPACED** | joined ✓ shared |

**Note on #4 (all-friends):** the finding classifies all-friends as NON-SPACED. It currently renders SPACED with a rich balance row + chevron. Converting it to a joined `CardColumn` is a distinct visual change (rows lose their card gaps and shadow-per-row). Deferred to REMAINING to keep this slice verifiable — see below.

## STEP 2 — shared presets

- **NON-SPACED:** already shared → `CardColumn` (`lib/widgets/card_list_view_builder.dart`). Keep. F138 & settings use their own ad-hoc joined variants; those can later route through `CardColumn`, but F138/settings joined lists are visually correct today so not urgent for this slice.
- **SPACED:** create ONE shared widget `SpacedCardList` in `lib/widgets/restyle/spaced_card_list.dart`. It maps a list of item widgets to a `Column`/`ListView` of `SoftCard`s separated by a consistent gap (default 10, the group-list value — the dominant spaced list). Keeps SoftCard radius/shadow tokens. Small, mirrors `CardColumn`.

## STEP 3 — slice applied THIS iteration

**DONE:**
- Create `SpacedCardList` (+ `spacedCardChildren` helper for the friend-list stagger case, which needs the spaced items as a flat `List<Widget>` to interleave with section labels).
- Route **group list** (#1) through the shared spaced gap.
- Route **friends screen requests** (#2, #3) through the shared spaced gap.

**REMAINING (documented, not done this slice):**
- #4 all-friends → NON-SPACED `CardColumn` conversion (visual change; needs its own audit pass for the balance-row-in-joined-card layout + tests).
- #5 settings + #6 F138 joined lists → optionally route through `CardColumn` for a single non-spaced impl (currently correct, low value).

**Status: PARTIAL.** Spaced preset now shared and applied to group list + friend requests. All-friends non-spaced conversion + joined-list consolidation remain.
