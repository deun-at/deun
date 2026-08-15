# expense-notification-route — Expense notifications open the read view, not the editor

## Spec
- Source: idea (user bug report, 2026-08-11: "expense notification jumps to the edit page of the
  expense not the expense view page")
- Flight: —
- Goal: Tapping an expense push notification lands on the expense read view, the same place tapping
  the expense in the list lands.

## Contract
- Acceptance:
  - Tapping an expense push notification opens the expense read view (`ExpenseDetailRead`), never the
    editor (`ExpenseDetail`).
  - This holds both when the app is in the background and when it is launched cold from the
    notification, since those are two separate entry points into the same handler.
  - Dismissing that view returns to the group detail underneath it, leaving no editor on the
    navigation stack and no unsaved-changes prompt.
  - Group notifications still open the group detail and friendship notifications still open the
    friends tab, unchanged.
  - An itemized expense opened from a notification lands on the same read view the in-app expense
    list already routes it to, so the two entry points cannot diverge again.
  - `flutter analyze` and `flutter test` pass.
- Provides: `navigateToExpense(BuildContext, Expense)` routing through the shared
  `openLedgerExpense(BuildContext, Group, Expense)` opener (moved from
  `group_detail_list.dart` into `helper.dart`), so notifications, the ledger tap and the
  expense search all resolve to the same destination
- Consumes: —
- Decisions:
  - Route to the read view rather than making the editor read-only -> the read view already exists and
    is already what the in-app list uses; the divergence is the bug.
  - Fix inside `navigateToExpense` rather than at the notification handler -> it is the single shared
    entry point, so both the cold-start and background paths are corrected at once and any future
    caller inherits the fix.
- Units:
  - Point `navigateToExpense` at the `expense-detail` route with the arguments `ExpenseDetailRead`
    expects.
  - Confirm both notification entry points (cold start and background) and the resulting back stack.
- Blockers: —

## Approach
The cause is pinned. `lib/navigation.dart` declares two sibling routes under `/group/details`:
`expense`, which builds `ExpenseDetail` (the editor, whose `expense` argument is nullable precisely
because it doubles as the create screen), and `expense-detail`, which builds `ExpenseDetailRead`.
`navigateToExpense` in `lib/helper/helper.dart` pushes the first one, so every expense notification
has been opening the editor.

Both notification entry points funnel through `_handleMessage` in `lib/navigation.dart`, which calls
`navigateToExpense` for the `expense` type, so a single change covers the cold-start path
(`getInitialMessage`) and the background path (`onMessageOpenedApp`). Note that `navigateToExpense`
pushes the group detail first and then the expense on top of it — worth confirming the back stack
still unwinds correctly once the second push targets a different route.

- Likely touchpoints: `lib/helper/helper.dart` (`navigateToExpense`), `lib/navigation.dart`
  (route names only, for reference)
- Depends: —
- Parallel-with: expense-editor-edit-labels

status: done

## Evidence

- **Notification opens `ExpenseDetailRead`, never `ExpenseDetail`** — proved red→green:
  before the fix `navigateToExpense` pushed `/group/details/expense` unconditionally; after
  the fix it delegates to `openLedgerExpense`. Tests
  `navigateToExpense a cold-start notification opens the read view, not the editor` and
  `navigateToExpense the read view gets the group and expense ExpenseDetailRead reads`
  (`test/helper/navigate_to_expense_test.dart`) assert the visited stack ends at
  `/group/details/expense-detail`, never includes `/group/details/expense`, and that the
  route receives the exact `group`/`expense` extras `ExpenseDetailRead` reads.
- **Holds for both cold start and background entry points** — both funnel through the same
  `_handleMessage` (`lib/navigation.dart:531-561`), so one fix covers both; test
  `navigateToExpense a background notification from another tab opens the same read view`
  drives `navigateToExpense` from a non-initial starting route (`/friend`) and asserts the
  same outcome as the cold-start case (`/group`).
- **Dismissing returns to the group detail, no editor on the stack, no unsaved-changes
  prompt** — test
  `navigateToExpense dismissing the read view returns to the group detail underneath` pops
  the pushed route and asserts the group detail stub is what remains visible, with
  `/group/details/expense` absent from the visited-route list for the whole flow.
- **Itemized expense lands wherever the in-app list already routes it, so the two entry
  points cannot diverge** — tests
  `navigateToExpense an itemized claim expense goes exactly where the ledger sends it` and
  `navigateToExpense an old itemized expense with no claim units opens the read view` each
  run `navigateToExpense` and `openLedgerExpense` side by side on the same expense and
  assert identical last-visited routes (`/group/details/claim` for claim-unit expenses,
  `/group/details/expense-detail` otherwise). The pre-existing `openLedgerExpense` regression
  tests at `test/widgets/group_detail_ledger_test.dart:428-446` kept passing unchanged,
  confirming the move changed no behavior.
- **Group and friendship notifications unchanged** — tests
  `the other notification types are unchanged a group notification still opens the group detail`
  and `... a friendship notification still opens the friends tab` cover `navigateToGroup` and
  `navigateToFriends`, neither of which this unit touched.
- **Gates**: `flutter analyze` — "No issues found!". `flutter test` — "All tests passed!",
  1057 tests (full suite, including the 9 new tests in
  `test/helper/navigate_to_expense_test.dart`).
- **Review verdict**: independent review returned `review: clean` on the first round — no bug
  or lean findings.
- Commit: `345ea1f` — files: `lib/helper/helper.dart`,
  `lib/pages/groups/presentation/group_detail_list.dart`,
  `test/helper/navigate_to_expense_test.dart`.
