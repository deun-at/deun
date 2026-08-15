# expense-editor-edit-labels — Editing an expense never says "Add expense"

## Spec
- Source: idea (user bug report, 2026-08-11: "edit expense has a wrong label 'add expense'")
- Flight: —
- Goal: Every label on the expense editor reflects which mode it is in. Opening an existing expense
  to edit it reads as editing, in both languages.

## Contract
- Acceptance:
  - Opening an existing expense for editing shows no label anywhere on the screen that reads "Add
    expense" or "Ausgabe hinzufügen" — this covers the header, the primary confirm button, section
    labels and any bottom-sheet titles reachable from the editor, not just the one surface reported.
  - Creating a new expense is unchanged and still reads as adding.
  - Both locales are correct; the German edit label is not left as the English one or vice versa.
  - Any money- or mode-related l10n key that turns out to have no Dart callers is deleted rather than
    left in the ARB files.
  - `flutter analyze` and `flutter test` pass.
- Provides: —
- Consumes: —
- Decisions:
  - Write the contract against the whole editor rather than the single reported label -> the header
    already branches correctly on new-versus-edit, so the reported label is a different surface, and
    fixing only what was named risks leaving a sibling label wrong.
  - Branch the existing label on edit mode rather than introducing a new screen -> the editor is one
    widget serving both modes by design; only its copy is mode-blind.
- Units:
  - Identify the offending surface: `expenseAddButton` ("Add expense" / "Ausgabe hinzufügen") is
    declared in both ARB files and is the prime suspect, but no direct Dart caller turned up in a
    grep of `lib/pages/expenses`, so it is either referenced indirectly or the label comes from a
    shared widget.
  - Make that label mode-aware in both locales, adding an edit-mode key if one does not exist.
  - Sweep the rest of the editor and its sheets for other new-only copy shown while editing.
- Blockers: —

## Approach
Half of this is already correct, which is the useful thing to know going in. The header in
`lib/pages/expenses/presentation/expense_detail.dart` branches on whether an expense was passed and
picks `expenseDetailTitleNew` ("New expense" / "Neue Ausgabe") or `expenseDetailTitleEdit` ("Edit
expense" / "Ausgabe bearbeiten"). Both keys exist and both translations are right. So the reported
label is coming from somewhere else on the same screen.

`expenseAddButton` resolves to exactly the reported string in both languages and is the obvious
candidate for the confirm button, but a grep of `lib/pages/expenses` found no `l10n.` reference to
it, so the first unit is genuinely a search rather than an edit — check shared widgets, the header
trailing action, and any indirect lookup. If it turns out to have no callers at all, then the visible
label is a third string and the search continues; either way that dead key should go.

Worth doing the sweep in the same pass: the editor also opens sheets and section labels that were
written for the create flow, and a mode-blind string in one of them will read exactly as wrong as
this one.

- Likely touchpoints: `lib/pages/expenses/presentation/expense_detail.dart`,
  `lib/pages/expenses/presentation/expense_entry_widget.dart`, shared header/button widgets under
  `lib/widgets/`, both ARB files
- Depends: —
- Parallel-with: expense-notification-route

status: planned
