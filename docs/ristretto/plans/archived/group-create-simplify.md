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
- Provides:
  - `GroupRepository.resolveSaveMembers({required bool isCreate, required String? membersJson, required String? currentUserEmail}) -> List<Map<String, dynamic>>` (`lib/pages/groups/data/group_repository.dart`) — pure decision of the `group_member` rows a save submits: one creator row (email only, no placeholder) on create, the full roster on edit.
  - `GroupRepository.decodeGroupMembersString` (same file) — plain JSON decoder now, with the old empty-list-injects-a-placeholder-member fallback removed.
  - `DeunHeader`'s measured trailing-actions layout (`lib/widgets/restyle/deun_header.dart`) — Row-based trailing slot that measures its own width and reserves it for the title, with an absolute 120dp title-readability floor, replacing the old symmetric-per-action Stack inset. `group_detail.dart`'s new `Icons.group_add` header action is the first three-action consumer.
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

## Evidence

Build plan: `.ristretto/build/group-create-simplify.md` (deleted after archiving; TDD order was Unit
3a/Unit 1 tests red -> Unit 1 code green -> Unit 3b rebases green -> l10n -> Unit 2 tests red -> Unit
2a/2b code green -> Unit 3a equivalence tests green last).

| # | Acceptance criterion | Proven by (red -> green) |
|---|---|---|
| 1 | Create renders exactly three inputs; no member search/chips/guest-add in the tree | `test/widgets/group_edit_screen_test.dart`: *"the create form carries exactly three inputs: name + colour, tracking mode, currency"* — asserts the `FormBuilder`'s registered field keys are exactly `{name, color_value, simplified_expenses, currency_code}` and that `GroupMemberSearch`, the owner tag, "Add guest" link and inline friend rows are all absent even with a friend available to show them. |
| 2 | Edit unchanged in field set and order | `test/widgets/group_edit_screen_test.dart`: *"no layout regression: section order, full-width fields and sticky footer (create and edit)"* (edit half re-asserts colour < members < tracking mode < currency) and *"every form field renders in a single Column under the FormBuilder, wrapped by one outer scroller"*. |
| 3 | Create persists exactly one `group_member` row (the creator); no placeholder row | `test/model/group_repository_test.dart`: *"a create submits exactly one row: the creator, and nothing else"*, *"a create with no signed-in user submits no row at all"*, *"an empty payload never becomes a placeholder member row"*; `test/pages/groups/group_create_simplify_test.dart`: *"the create write path is handed no member field at all"*. |
| 4 | After create: lands on the new group's detail page, with a single-tap add-members affordance | `test/pages/groups/group_create_simplify_test.dart`: *"a successful create lands on the NEW group detail page"*, *"the group detail page carries a single-tap add-members affordance"* (asserts the action sits inside `DeunHeader`, is hit-testable without scrolling, and one tap reaches the member surface; search and edit actions stay untouched). |
| 5 | Create-then-add-in-edit == old create-with-members (rows *and* balances) | `test/model/group_repository_test.dart`: *"create-then-add-in-edit writes the same group_member rows as the old create-with-members flow"*, *"...and the same balances"* (90 paid by the creator, split three ways -> each of the other two owes 30 under both the old and new paths). |
| 6 | Name-only create succeeds with the existing mode default and EUR | `test/widgets/group_edit_screen_test.dart`: *"creating with only a name keeps the create defaults: Simplified and EUR"*. |
| 7 | Existing group-create widget/model tests pass or have the member assertions deleted, not weakened | Rebased onto the edit form, assertions kept verbatim: *"members section shows Owner tag, Add guest link and inline greyed friend rows (F71)"*, *"tapping an inline friend row adds them (removes from candidates) (F71)"*. Rebased onto a `GroupMemberSearch` harness (the create form no longer hosts the member section): *"with no persisted group, removing a chip never calls the removal path"*. |

Two review rounds ran against the build (see Review verdict below). The findings' regression
coverage:

- Notification correctness (roster-diff on the edit path only) — `test/model/group_repository_test.dart`:
  *"notifies only the members this save actually adds"*, *"a create submits the creator alone, so
  nobody is left to notify"*, *"a member re-added after removal is notified again"*.
- `DeunHeader` trailing-inset measurement (three actions still leave a readable title) —
  `test/widgets/deun_header_test.dart`: *"on a narrow phone, THREE trailing actions still leave the
  title a readable width (and never overlap them)"* (360dp viewport, asserts title width >= 120dp and
  never paints under the actions).
- The follow-up lean finding — proportional centering threshold replaced by an absolute 120dp floor —
  `test/widgets/deun_header_test.dart`: *"on a narrow phone, TWO trailing actions still keep the title
  optically centered (regression: a proportional centering floor over-triggered here even though
  120dp of title clears the readability bar)"*.

### Gate summary

- `flutter analyze` — `No issues found! (ran in 5.4s)`.
- Targeted run (`flutter test test/model/group_repository_test.dart test/widgets/group_edit_screen_test.dart test/pages/groups/group_create_simplify_test.dart test/widgets/deun_header_test.dart`) — `+75: All tests passed!`, 0 failures.
- Full suite (`flutter test`) — `+1049: All tests passed!`, 0 regressions.
- No database change: `save_group_all` (migration `20260815010000_group_member_removal.sql`, already
  applied by `group-member-removal`) inserts one `group_member` row per submitted member and never
  deletes, so this feature needed no migration and has no `MANUAL_OPS.md` entry.

### Review verdict

Round-1 review raised 3 bugs + 3 lean findings, all fixed:

- Notifications had followed the members off the create path (the roster-diff notify call needed to
  move to the edit save, where members are now actually added) — fixed, see notification tests above.
- `DeunHeader`'s "a third action needs no layout change" assumption was wrong: a symmetric 3x48dp
  title inset left ~44dp of group name on a 360dp phone — fixed by measuring the trailing Row and
  giving the title the remaining band.
- The Unit 3 equivalence tests (rows/balances) were tautological, proving only their own `Set`
  dedup — fixed by extracting `GroupRepository.resolveMemberWrite` and replaying both the old and new
  flows through it against a fake `group_member` table.
- Three additional lean findings, also fixed (roster ordering, decoder doc comment, test harness
  duplication).

Round-2 review verified all six resolved with no new defects, and cleared the flagged `DeunHeader`
centering judgment call as an acceptable implementation choice consistent with
`docs/design_handoff/COMPONENTS.md` §2. One follow-up lean finding from round 2 — replace the
proportional centering threshold with an absolute 120dp floor — was then also fixed (see the
narrow-phone TWO-actions regression test above).

Final gates at close: `flutter analyze` clean, `flutter test` 1049 passing.

status: done
