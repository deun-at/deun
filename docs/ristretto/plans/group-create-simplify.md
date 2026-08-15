# group-create-simplify — Group creation asks for name, mode and currency only

## Spec
- Source: idea (NOTES.md idea 4, Jakob 2026-07-24, branch `claude/group-management-issues-ifybxc`)
- Flight: group-membership
- Goal: Cut the create-group flow down to the three decisions that must be made up front, and move member management entirely into the group's own surface.

## Contract
- Acceptance:
  - The create-group form (`widget.group == null`) renders exactly three inputs: name + colour, tracking mode (simplified/normal), and currency. No member search, no member chips, no guest-add affordance is present in the widget tree.
  - The edit-group form is unchanged in field set and order — it keeps its member section until `group-member-add-flow` replaces it. Create and edit visibly diverge; this is intentional.
  - Creating a group persists exactly one `group_member` row: the creator. No empty-string or placeholder member row is written (today's `decodeGroupMembersString` fallback inserts a member with `display_name: ''` — that path must not survive into the new create flow).
  - After a successful create, the user lands on the new group's detail page with a visible, single-tap affordance to add members.
  - A group created through this flow and then given members through the existing edit form produces the same `group_member` rows and the same balances as the old create-with-members flow did — proven by a repository-level test comparing both paths.
  - Creating a group with only a name, leaving mode and currency at their defaults, succeeds and yields tracking mode = the existing create default and currency = EUR.
  - Existing group-create widget/model tests pass or are updated with their assertions on the removed member field deleted, not weakened.
- Provides: —
- Consumes: —
- Decisions:
  - Currency stays on create -> changing a group's currency later only **relabels** amounts, it never converts them, so the decision genuinely belongs at creation time. This preserves the shipped `multi-currency-foundation` acceptance criterion "create (default EUR)". (Jakob, prep 2026-08-15)
  - Member management leaves create entirely — not collapsed, not behind an "advanced" toggle. Half-measures keep the form-field-disposal risk that caused the original save bug.
  - Create and edit intentionally diverge for one release rather than blocking this on `group-member-add-flow`. Members remain reachable through group edit in the interim, so no functionality is lost.
- Units:
  - Strip the member field from the create branch of the form and remove the now-dead empty-member fallback on the create path.
  - Post-create routing to group detail plus the add-members affordance there.
  - Test updates: create-path repository equivalence test, plus the existing group-edit tests rebased on the new field set.
- Blockers: —

## Approach
- `GroupEdit` serves both create and edit off a single `FormBuilder`, branching on `_isEdit`. The cheapest correct move is to make the member field conditional on that same branch rather than forking the widget — but note that a conditional `FormBuilder` field is exactly the shape that interacts badly with `clearValueOnUnregister`, which is why this feature is sequenced **after** `group-form-field-structure` lands the Column restructure. Do not reorder those two.
- Watch the sticky footer and the edit-only actions block: removing a section from create changes the form's height and can expose layout assumptions that only held when the member list was there.
- Likely touchpoints: lib/pages/groups/presentation/group_detail_edit.dart (the create branch), lib/pages/groups/data/group_repository.dart (`decodeGroupMembersString` fallback), lib/navigation.dart (post-create route), lib/pages/groups/presentation/group_detail.dart (add-members affordance).
- Depends: group-form-field-structure
- Parallel-with: group-member-removal

status: planned
