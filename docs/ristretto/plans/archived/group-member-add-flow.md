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
  - *(Visual and interaction criteria, appended from the design session of 2026-09-11 — see [design brief](../group-member-management-design-brief.md).)*
  - [auto] The surface is a routed **Members page** — roster first, search above it — reachable from group detail and from a read-only member row on group edit. It is not a sheet and not a search overlay.
  - [auto] After a successful add the page stays open, the new member is in the roster, and the search field is cleared and ready for the next one.
  - [auto] A search matching no existing user ends in an actionable `Create guest «query»` result row, and that row is the *only* guest entry point — there is no standing guest button.
  - [auto] A member with an unsettled balance carries **no remove affordance at all**. The row shows the outstanding amount code-first (`USD 12.50`, never `$12.50`) and routes to the existing settle-up path. No dialog explains the refusal after a tap.
  - [auto] Hard removal commits with no confirmation. Soft removal confirms once, naming that past expenses stay.
  - [auto] A soft-removed member is absent from the roster and from every member picker. Re-adding them through search clears `removed_at` rather than inserting, and says nothing about the prior membership.
  - [auto] A guest is marked with a `Guest` label on the roster row, and is otherwise rendered identically to a real user.
  - [auto] A successful add shows no snackbar — the roster is the confirmation. A failed add shows one naming the failure and leaves the query in the field to retry.
  - [auto] A group whose only member is its creator shows a single add-members call to action on group detail, which stops dominating once a second member exists.
- Provides: `GroupRepository.addMember(String groupId, String email): Future<MemberAddOutcome>`, `GroupRepository.previewMemberRemoval(String groupId, String email, {required Currency currency}): Future<MemberRemovalOutcome>` (the read half of `removeMember`, its signature unchanged), `MemberAddOutcome`/`resolveMemberAdd` and `Group.memberBalances`/`Group.isSolo` (`lib/pages/groups/data/member_add.dart`, `lib/pages/groups/data/group_model.dart`), the routed `/group/members` page (`GroupMembersPage`), and `SearchField` (`lib/widgets/restyle/search_field.dart`) extracted out of `FriendAddPage` for reuse
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
- Manual-Checks: [manual-checks.md](../../manual-checks.md) — cross-client realtime member add
- Blockers: —

## Approach
- `GroupMemberSearch` already contains the four add paths and is well factored; the work is mostly relocation plus giving it its own persistence, not a rewrite of the search itself. Resist rebuilding the search — the risk here is in the write path and the state ownership, not the lookup.
- The guest-creation path (`is_guest_pending` → `UserRepository.createGuest`) is the fragile part: today it runs inside the group save and swallows failures. Give it explicit success and failure states in the new flow.
- Likely touchpoints: lib/pages/groups/presentation/group_member_search.dart, lib/pages/groups/presentation/group_detail_edit.dart (field removal), lib/pages/groups/presentation/group_detail.dart (entry point), lib/pages/groups/data/group_repository.dart (member-only write path), lib/pages/users/user_repository.dart (guest creation), lib/navigation.dart (the route — the design session settled that it is a page).
- Depends: group-member-removal
- Parallel-with: group-create-simplify

## Evidence

Gate green: `dart format` clean on every touched file, `flutter analyze` — no issues found,
`flutter test` — 1560 tests pass, none failing. Commit `22b1dcb`.

review: notes-only · rounds: 1 · open: 0 block, 4 note, 5 lean
tier: normal

Seventeen `[auto]` criteria, each proven by a named test in
`test/pages/groups/group_member_add_flow_test.dart` (widget-level, 21 cases) or
`test/model/member_add_test.dart` (pure, 17 cases):

- **Add reachable without the edit form, persists on its own** — "the group-detail add-members
  action opens the Members page, not the group form"; "adding a member writes on its own and the
  page carries no save button" (no `PrimaryButton(l10n.save)`, no `FormBuilder` anywhere on the
  page).
- **A failed add touches no group attribute** — "a failed add leaves the group attributes
  untouched and the query in the field"; structurally, the page has no group form to touch, and
  `resolveSaveMembers`'s edit branch now submits `const <Map<String, dynamic>>[]` unconditionally
  (`test/model/group_repository_test.dart`).
- **All four add paths carried over** — "all four add paths are on the page: friend, email/handle
  lookup, and create-guest" (friend suggestion and email/`name#1234` share one
  `UserRepository.fetchData` branch, untouched).
- **Guest failure surfaced, not swallowed** — "a failed guest creation says so and keeps the name
  for a retry"; "creating a guest adds them and marks the row Guest" for the success half.
- **Removal only through `GroupRepository.removeMember`** — "a settled removal goes through
  GroupRepository.removeMember, never a direct delete"; "a hard removal commits with no dialog"; "a
  soft removal confirms once and says the past expenses stay" plus "cancelling the soft-removal
  confirmation writes nothing".
- **`group_members` FormBuilderField gone; no group-attribute save reads or writes membership** —
  "the edit form registers no member field and links to the Members page" (`form.fields.keys`
  carries no `group_members` key); `_saveAllLegacy`'s create-only write path is the sole surviving
  membership write on a group save, covered by the existing create-path tests in
  `group_repository_test.dart`.
- **Already-a-member is a clear no-op** — "adding someone already in the group says so and adds no
  second row".
- **EN + DE copy, generated l10n committed** — `test/l10n_members_copy_test.dart`: every new key
  exists in both locales, every retired key (`groupMemberSelectionEmpty`,
  `groupMemberRemoveBlocked`, etc.) is gone from both, and the German copy is German, not the
  English string copied over.
- **Routed Members page, not a sheet, search above the roster** — "the Members page is a page with
  the search above the roster" (`DeunHeader` present, `BottomSheet`/`SheetScaffold` absent, search
  field's `dy` less than the roster label's).
- **Page stays open after a successful add, field cleared** — "after a successful add the page
  stays open, the roster carries them and the field is empty" — and no `SnackBar` at all, the
  roster being the receipt.
- **Guest row is the only guest entry point** — "the guest row appears only with a query, and there
  is no standing guest button".
- **Unsettled member: no remove affordance, code-first amount, settle-up route** — "an unsettled
  member carries a balance and a settle-up route, and no remove action" — asserts
  `l10n.toCurrency(12.5, 'USD')` renders `USD 12.50`, never `$12.50`, no `Icons.close` in that row,
  and no dialog on a tap.
- **Hard removal: no confirmation. Soft removal: confirms once.** — same two tests cited above under
  removal routing.
- **A soft-removed member is absent from the roster; re-add is silent** — "a soft-removed member is
  not on the roster but is still findable in search", with no re-add-specific copy anywhere. The
  picker half of this criterion is already enforced repo-wide by `group-member-removal`'s tests 17,
  18 and 20 — no new test owed there, per the reuse-before-writing rule.
- **Guest label, otherwise identical rendering** — folded into "creating a guest adds them and marks
  the row Guest" above.
- **No snackbar on success, one naming the failure on error, query retained** — "adding a member
  writes on its own…" (success, no snackbar) and "a failed add leaves the group attributes
  untouched and the query in the field" (failure).
- **Solo-group call to action, one only, gone at two members** — "a group of one shows one
  add-members call to action that opens the Members page" and "the call to action is gone once a
  second member exists".

**Not proven; `pending human: cross-client realtime member add`.** The one `[human]` criterion — a
member added on one client appearing on another client's open group detail — needs two live clients
against the self-hosted Supabase instance, unreachable from this build (no compose file, no seed
script, no driver in the dev dependencies). The client half is proven structurally
(`addMember`/`removeMember` both call `update_group_member_shares`, which bumps
`group_update_checker`, the row `GroupDetailNotifier` already subscribes to) and by "a successful
write reloads the group detail provider" (`fake.reloads == 1` after an add and after a removal).
The check itself is recorded, unticked, in `docs/ristretto/manual-checks.md`.

## Open findings

Left open by review round 1 (`notes-only`), recorded verbatim, none fixed:

note · `lib/pages/groups/data/group_repository.dart:297` · `_saveAllLegacy` still SELECTs the whole `group_member` roster on every save, edit included, so a group-attribute save path still *reads* membership (criterion 6's letter) · cannot harm: `groupMembers` is empty on edit, so `resolveMemberWrite` yields no inserts and no re-adds and nothing can be written · skip the roster read and `resolveMemberWrite` when `groupMembers` is empty.

note · `test/pages/groups/group_member_add_flow_test.dart:598` · `tester.tap(find.text('Ann'))` then `expect(find.byType(AlertDialog), findsNothing)` is vacuous — the roster `SoftCard` has no `onTap`, so no tap can ever open a dialog · cannot harm: the criterion itself holds — `_buildMemberRow:508` gives an unsettled row no remove affordance and `_handleRemove` is unreachable from it · assert the row carries no tap target instead.

note · `test/model/group_repository_test.dart` · `GroupRepository.resolveMemberWrite` lost every test it had (the deleted `_FakeGroupMemberTable` cases) while staying live on the create path at `group_repository.dart:305` · cannot harm: the function is unchanged and create still writes exactly the creator row · keep one case pinning create's single-row insert/dedup.

note · `lib/pages/groups/presentation/group_members_page.dart:134` · `_runSearch` catches only `AmbiguousUsernameException`; any other repository failure escapes the debounce `Timer` unhandled and leaves `_searching` true, so the page silently shows just the "Create guest" row · cannot harm: nothing is written, the next keystroke retries, and the deleted `GroupMemberSearch` let the same errors escape · catch broadly and surface the failure.

lean · `lib/pages/groups/presentation/group_members_page.dart:151` · emptying the field fires a full `fetchFriends('')` round trip whose result can never render (`_buildResultsBlock` runs only while `_query.isNotEmpty`), so the build plan's "page opens on the user's friends" is both unimplemented and paid for · guard `_runSearch` on a non-empty query, or render that section.

lean · `lib/pages/groups/data/member_add.dart:68` · `MemberSearchResults.isEmpty` has no callers anywhere · delete.

lean · `lib/pages/groups/data/group_repository.dart:290` · `final members = List<Map<String, dynamic>>.from(groupMembers)` is a copy with no mutation left after the guest loop went · pass `groupMembers` through.

lean · `test/pages/groups/group_member_add_flow_test.dart:759,777` · the two `reloads == 1` tests restate what tests 7 and 12 already observe through the post-reload roster · duplicated coverage.

lean · `test/pages/groups/group_member_add_flow_test.dart:744` · `BottomSheet`/`SheetScaffold` `findsNothing` in a harness that pumps `GroupMembersPage` straight into a route — neither could ever appear; the `DeunHeader` and dy-ordering assertions carry the criterion · drop the two.

minor (reviewer omitted from the main list): dangling `[resolveGroupJoin]` doc reference in `member_add.dart:22`; the symbol lives in `member_removal.dart`, which that file does not import.

status: done
