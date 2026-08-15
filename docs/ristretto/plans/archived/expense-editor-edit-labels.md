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
- Provides: `AppLocalizations.expenseSaveAndShareForClaimingEdit` (new ARB key, both locales);
  `bool get _isEdit` on `_ExpenseDetailState` (private, mirrors `group_detail_edit.dart`'s pattern).
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

## Evidence

- **Acceptance 1** ("no 'Add expense' / 'Ausgabe hinzufügen' anywhere while editing — header,
  confirm button, section labels, sheet titles"): the sweep in the build plan checked every surface
  the editor opens and found only the footer CTA mode-blind (header was already correct; section
  labels, add-item button, sheets, discard/receipt/delete dialogs are all mode-neutral copy). Fixed
  by branching the CTA on the new `_isEdit` getter
  (`lib/pages/expenses/presentation/expense_detail.dart:107-111`, CTA at `:1218-1227`). Proven by
  `test/widgets/expense_editor_edit_labels_test.dart`:
  - `editing a quick expense never says "Add expense" (en)` — red before the fix (CTA read
    `expenseAddButton`/"Add expense" while editing), green after.
  - `editing an itemized expense uses the edit share CTA (en)` — same shape, itemized branch.
  - Both mirrored in German: `editing a quick expense never says "Ausgabe hinzufügen" (de)`,
    `editing an itemized expense uses the edit share CTA (de)`.
- **Acceptance 2** ("creating a new expense is unchanged and still reads as adding"): proven by
  `creating a new expense still reads as adding (en)`, `creating a new expense still reads as
  adding (de)`, and `new expense toggled to Itemized keeps the add share CTA` — all assert the
  original `expenseAddButton` / `expenseSaveAndShareForClaiming` strings still show and the new
  edit-only strings do not.
- **Acceptance 3** ("both locales correct; German edit label not left as English"): proven by
  `test/l10n_editor_labels_test.dart`'s `the editor edit labels differ between en and de`, which
  asserts the literal German values ("Speichern", "Speichern & zum Beanspruchen teilen") and that
  each differs from its English counterpart — not just that a translation exists.
- **Acceptance 4** ("callerless money/mode l10n key deleted rather than left in the ARB files"):
  14 keys (`createExpense`, `editExpense`, `addExpenseTitle`, `expenseAmount`,
  `expenseAmountValidationEmpty`, `expenseEntryTitle`, `expenseYourNetLabel`, `expenseYouLent`,
  `expenseYouOwe`, `expenseEntryAmount`, `expenseEntrySharesLable`, `totalExpensesAmount`,
  `splitModeAmount`, `totalLabel`) were verified at 0 callers by
  `grep -rn "\.<key>\b" lib test --include=*.dart` (excluding the generated `app_localizations*.dart`
  files) and removed from both ARB files with their `@`-metadata. Proven by
  `callerless money/mode keys are deleted from both ARB files` (all 14 absent from both files, English
  `@`-metadata gone too) and `the new edit key exists in both ARB files` (confirms the sweep didn't
  overshoot and delete the one key that was added).
- **One pre-existing assertion adapted, not weakened**: `test/widgets/expense_itemized_editor_test.dart`
  pumps saved (edit-mode) expenses in three places, so its CTA assertions changed from
  `expenseAddButton` to `save`/`expenseSaveAndShareForClaimingEdit` once the editor became mode-aware:
  - `:362` — `editing a shared expense regroups claim units into one qty-N item card (F146)`: now
    asserts `expenseSaveAndShareForClaimingEdit` shows and `expenseSaveAndShareForClaiming` +
    `expenseAddButton` do not (previously asserted nothing about the CTA) — strictly stronger.
  - `:665` — `itemized expense reads its saved category back (not Other)`: same addition, asserts
    the edit CTA shows.
  - `:748` — `collapsing a multi-item itemized expense to Quick seeds the summed total`: was
    `expect(find.text(l10n.expenseAddButton), findsOneWidget)`; now
    `expect(find.text(l10n.save), findsOneWidget)` plus an added
    `expect(find.text(l10n.expenseAddButton), findsNothing)` — equally strict on the positive
    assertion (still checks exactly one CTA shows), plus a negative check the old version lacked.
  Independent review confirmed all three are strictly equal or stronger than before, not weakened.

### Gate summary

- `flutter analyze` — clean, no issues found.
- `flutter test` — full suite green: **1068 passed**, 0 failed.
- New tests isolated: `test/widgets/expense_editor_edit_labels_test.dart` (7 tests) +
  `test/l10n_editor_labels_test.dart` (4 tests) — all 11 pass standalone.

### Review verdict

Independent review confirmed every acceptance criterion satisfied. It specifically audited the
three adapted pre-existing assertions in `expense_itemized_editor_test.dart` (`:362`, `:665`,
`:748`) and found all three strictly equal or stronger than before, not weakened. It also verified
all 14 deleted ARB keys have zero callers and that the German replacement values are real
translations, not the English copy left in place.

### Out of contract — not fixed

Saving an *edited* expense still shows the `expenseCreateSuccess` / `expenseCreateError` snackbars
(`lib/pages/expenses/presentation/expense_detail.dart:913`, shown at `:911` before the
`Navigator.pop` at `:927`, so it renders over the still-mounted editor). AC1's enumerated surfaces
do not name snackbars, so the acceptance bar is met, but the plan's Goal line ("Every label on the
expense editor reflects which mode it is in") is not fully served by this fix. Fixing it needs new
`expenseUpdateSuccess`/`expenseUpdateError` copy in both ARBs — user-facing wording no plan has
decided, so it is left for a future feature rather than fixed here.

status: done — commit `57891ae`
