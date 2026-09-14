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
  - *(Visual and interaction criteria, appended from the design session of 2026-09-11 — see [design brief](group-member-management-design-brief.md).)*
  - [auto] The surface is a routed **Members page** — roster first, search above it — reachable from group detail and from a read-only member row on group edit. It is not a sheet and not a search overlay.
  - [auto] After a successful add the page stays open, the new member is in the roster, and the search field is cleared and ready for the next one.
  - [auto] A search matching no existing user ends in an actionable `Create guest «query»` result row, and that row is the *only* guest entry point — there is no standing guest button.
  - [auto] A member with an unsettled balance carries **no remove affordance at all**. The row shows the outstanding amount code-first (`USD 12.50`, never `$12.50`) and routes to the existing settle-up path. No dialog explains the refusal after a tap.
  - [auto] Hard removal commits with no confirmation. Soft removal confirms once, naming that past expenses stay.
  - [auto] A soft-removed member is absent from the roster and from every member picker. Re-adding them through search clears `removed_at` rather than inserting, and says nothing about the prior membership.
  - [auto] A guest is marked with a `Guest` label on the roster row, and is otherwise rendered identically to a real user.
  - [auto] A successful add shows no snackbar — the roster is the confirmation. A failed add shows one naming the failure and leaves the query in the field to retry.
  - [auto] A group whose only member is its creator shows a single add-members call to action on group detail, which stops dominating once a second member exists.
- Provides: —
- Consumes: `GroupRepository.removeMember(groupId: String, email: String): Future<MemberRemovalOutcome>`, `MemberRemovalOutcome` — from `group-member-removal`
- Decisions:
  - Membership writes are immediate and independent of the group form. This is the whole point of the refactor: coupling membership to a form submission is what produced both the name-corruption bug and the silent guest-drop.
  - Removal semantics are **not** redefined here — they are owned by `group-member-removal`, and this flow only presents them.
  - Removal is presented from the row, and **the outcome is resolved before anything is written** —
    it decides whether to confirm at all. This is the one structural consequence the design session
    produced; see the `Units:` seam below.
  - The former-member case adds no UI. A soft-removed person is invisible outside past expenses, so
    the roster inherits an absence rather than a third member state.
- Units:
  - **Members page + route**, entry points from group detail and from a read-only member row on
    group edit; delete the `group_members` `FormBuilderField` from `group_detail_edit.dart`.
  - **Member-only write path** on `GroupRepository`: add one member, committed on its own, sharing
    no transaction or form submission with `saveAll`.
  - **Relocate `GroupMemberSearch`** into the page as roster-plus-search. Keep the four add paths;
    the risk is in state ownership, not the lookup. Give the guest path its own name-entry step
    with explicit success and failure states, replacing today's silent `removeWhere`.
  - **Outcome-before-write seam.** `GroupRepository.removeMember` resolves *and* writes in one
    call, so the flow cannot decide whether to confirm without knowing the outcome first. Resolve
    it by one of: a dry-run that returns a `MemberRemovalOutcome` without writing, or deriving the
    settled/history facts from what the page already holds. **Pick one at pull time and record
    which** — this is the only unit the design session created rather than relocated, and the only
    place it can force a repository change.
  - **Row presentation of the three outcomes**: unsettled shows balance + settle-up and no remove;
    settled-with-history confirms once; settled-without-history commits silently.
  - **Empty state** on group detail for a group of one, opening the Members page.
  - EN + DE copy for every new string, with generated l10n committed.
- Manual-Checks: [manual-checks.md](../manual-checks.md) — cross-client realtime member add
- Blockers: —

## Approach
- `GroupMemberSearch` already contains the four add paths and is well factored; the work is mostly relocation plus giving it its own persistence, not a rewrite of the search itself. Resist rebuilding the search — the risk here is in the write path and the state ownership, not the lookup.
- The guest-creation path (`is_guest_pending` → `UserRepository.createGuest`) is the fragile part: today it runs inside the group save and swallows failures. Give it explicit success and failure states in the new flow.
- Likely touchpoints: lib/pages/groups/presentation/group_member_search.dart, lib/pages/groups/presentation/group_detail_edit.dart (field removal), lib/pages/groups/presentation/group_detail.dart (entry point), lib/pages/groups/data/group_repository.dart (member-only write path), lib/pages/users/user_repository.dart (guest creation), lib/navigation.dart (the route — the design session settled that it is a page).
- Depends: group-member-removal
- Parallel-with: group-create-simplify

status: planned
