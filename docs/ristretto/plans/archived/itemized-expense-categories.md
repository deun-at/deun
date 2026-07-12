# itemized-expense-categories — Expense-level category for itemized expenses

## Spec
- Source: idea (2026-07-12 planning session)
- Flight: —
- Goal: Itemized expenses carry an expense-level category like quick/simple expenses do, so they stop all landing in "Other" in lists and statistics.
- Acceptance:
  - The itemized editor exposes the same category selector as the quick layout; the chosen category saves and reads back on the expense (today itemized saves category as null, which reads back as `other` — F116 decision).
  - Scanning a receipt auto-detects the category from the merchant name in the itemized layout, same as the quick layout does today; the user can override it before saving.
  - An itemized expense saved with category X appears under X (not "Other") in the group statistics category sections and anywhere else the expense category is displayed.
  - Existing itemized expenses without a category continue to read as "Other" — no data migration required.
  - Per-item icons (item name → icon mapping) are unchanged; the expense-level category does not replace them.
  - `flutter analyze` and `flutter test` pass, including a test covering itemized save/read of a category.
## Approach
- The model, DB column, `ExpenseCategory` enum, `CategoryDetector`, and `CategorySelector` widget all exist and already work for quick expenses — this feature is UI plumbing: show the selector in the itemized branch of the expense editor and stop forcing null on save.
- This deliberately revisits F116 ("no expense-level Category row on itemized"); the category row returns *alongside* the per-item icons because statistics need a category per expense. Place the selector where it doesn't crowd the itemized item list (e.g. with the other expense-level fields near name/date).
- Auto-detection: the merchant-name → category hook exists for the quick path; extend it to fire in itemized mode too.
- Likely touchpoints: lib/pages/expenses/presentation/expense_detail.dart (itemized branch), lib/pages/expenses/data/ (only if save path hard-nulls category), lib/l10n/*.arb if new helper copy is needed.
- Decisions / tradeoffs: one category per expense (not per item) — matches the statistics data model and keeps the editor simple; per-item categories were considered and rejected as heavy.
- Depends: —
- Parallel-with: — (touches the same editor file as scan-split-even; pull sequentially)
- Blockers: —

status: done

## Evidence

Implementation: the model, DB column, `ExpenseCategory` enum, `CategoryDetector`, and
`CategorySelector` all already existed and are wired for the quick path. This feature was UI
plumbing in `lib/pages/expenses/presentation/expense_detail.dart`:
- Rendered a full-row `CategorySelector` (name `"category"`) in the itemized Details section,
  right after the Paid-by / When rows — replacing the F116 "no category row" block.
- Both quick and itemized selectors now pass `onChanged` to keep `_detectedCategory` in sync,
  so the chosen/auto-detected category survives Quick↔Itemized toggles.
- The save path (`ExpenseRepository.saveAll`, `formResponse['category']`) and read path
  (`Expense.loadDataFromJson` → `ExpenseCategory.fromString`) were already correct; adding the
  field is all that was needed to stop itemized saving `category` as null.

Each criterion proven by tests in `test/widgets/expense_itemized_editor_test.dart`:
- "Itemized layout exposes a category selector" — `CategorySelector` + `categoryLabel` render in
  itemized mode (same selector as quick).
- "itemized expense reads its saved category back (not Other)" — loading an itemized expense with
  category `food`, `formState.save()` then `value['category'] == ExpenseCategory.food` (the exact
  map `saveAll` persists as `category.name`); selector shows Food, not Other.
- "itemized expense without a category reads back as Other" — an uncategorized expense loads as
  `ExpenseCategory.other` and reads back as Other (no migration; statistics group under 'other').
- "itemized layout auto-detects category from the merchant name" — typing "Lidl" into the name
  field drives `CategoryDetector` and writes `ExpenseCategory.groceries` to the form field,
  same as the quick layout; user can override by tapping the selector.
- Per-item icons (`iconForItemName`) were not touched — expense-level category is additive.
- Pre-existing "itemized total updates live when an item quantity changes" was made robust with
  `ensureVisible` (the new category row pushes the item stepper below the test-viewport fold);
  the assertion (€7.50 after qty 2→3) is unchanged.

Gate summary (`.ristretto.json`): `dart format` applied; `flutter analyze` → "No issues found!";
`flutter test` → "All tests passed!" (914 tests, incl. the 4 new itemized-category tests).
