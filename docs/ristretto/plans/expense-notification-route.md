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
- Provides: `navigateToExpense(BuildContext, Expense)` routing to the read view
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

status: planned
