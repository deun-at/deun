# group-member-add-flow — Adding members as its own flow, not a form field

## Spec
- Source: idea (NOTES.md idea 5, Jakob 2026-07-24, branch `claude/group-management-issues-ifybxc`)
- Flight: group-membership
- Goal: Give adding and removing members a dedicated surface with its own state, instead of a search widget embedded as a value in the group form.

## Contract
- Acceptance:
  - [auto] Adding a member is reachable from the group detail page without entering the group edit form, and adding one member persists immediately — it does not require a subsequent group save.
  - [auto] A failed member add leaves the group's name, colour, tracking mode and currency untouched; member writes and group-attribute writes no longer share a transaction or a form submission.
  - [auto] The flow covers all four of today's add paths — existing user by username, by email, contact suggestion, and pending-guest creation — with no path lost.
  - [auto] Guest creation failure is surfaced to the user rather than silently dropped (today `saveAll` removes failed guests with `removeWhere` and says nothing).
  - [auto] Removal from this flow routes through `GroupRepository.removeMember` and honours its blocked/soft/hard outcomes; the flow never deletes a `group_member` row directly.
  - [auto] The `group_members` `FormBuilderField` is gone from `group_detail_edit.dart` entirely, and no group-attribute save path reads or writes membership.
  - [auto] Adding a member who is already in the group is a no-op with clear feedback, not a duplicate row.
  - [human] A member added by one client appears on another client's open group detail through the existing realtime path.
  - [auto] All new copy exists in EN and DE with generated l10n committed.
  - *(Visual and interaction criteria — sheet vs full page, empty state, ordering, confirmation style — are settled in the design session and appended here before this feature is pulled.)*
- Provides: —
- Consumes: `GroupRepository.removeMember(groupId: String, email: String): Future<MemberRemovalOutcome>`, `MemberRemovalOutcome` — from `group-member-removal`
- Decisions:
  - Membership writes are immediate and independent of the group form. This is the whole point of the refactor: coupling membership to a form submission is what produced both the name-corruption bug and the silent guest-drop.
  - Removal semantics are **not** redefined here — they are owned by `group-member-removal`, and this flow only presents them.
- Units:
  - *(To be filled once the design session lands — the unit breakdown depends on whether this is one screen or a sheet plus a detail row.)*
- Manual-Checks: [manual-checks.md](../manual-checks.md) — cross-client realtime member add
- Blockers:
  - Visual and interaction design for the standalone add/remove member flow -> design session with Jakob, against `docs/ristretto/plans/group-member-management-design-brief.md`. Until that lands, the acceptance list above has no visual criteria and `Units:` is unfilled, so this feature is not pullable.

## Approach
- `GroupMemberSearch` already contains the four add paths and is well factored; the work is mostly relocation plus giving it its own persistence, not a rewrite of the search itself. Resist rebuilding the search — the risk here is in the write path and the state ownership, not the lookup.
- The guest-creation path (`is_guest_pending` → `UserRepository.createGuest`) is the fragile part: today it runs inside the group save and swallows failures. Give it explicit success and failure states in the new flow.
- Likely touchpoints: lib/pages/groups/presentation/group_member_search.dart, lib/pages/groups/presentation/group_detail_edit.dart (field removal), lib/pages/groups/presentation/group_detail.dart (entry point), lib/pages/groups/data/group_repository.dart (member-only write path), lib/pages/users/user_repository.dart (guest creation), lib/navigation.dart (route, if it becomes a page).
- Depends: group-member-removal
- Parallel-with: group-create-simplify

status: planned
