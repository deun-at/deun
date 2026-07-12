# scan-split-even — Split a scanned receipt evenly

## Spec
- Source: idea (2026-07-12 planning session)
- Flight: —
- Goal: A scanned receipt can be split evenly among members instead of being forced through per-item claiming.
- Acceptance:
  - After scanning a receipt with multiple line items, the user can choose an even split without retyping anything; the resulting expense amount equals the receipt total (sum of all scanned line totals), not the first item's amount.
  - The even-split path produces a normal quick expense: equal shares among the selected group members, saved and displayed like any manually entered quick expense.
  - Collapsing a multi-item itemized editor into the quick layout seeds the expense amount with the *sum* of the item line totals (today it keeps only the first item's amount and silently drops the rest of the value).
  - When collapsing drops per-item detail, the UI says so before or as it happens (the user must not discover item loss after saving); switching back to itemized does not need to restore the dropped items.
  - Scanned-receipt claiming (itemized path) is unchanged and remains the default after a scan.
  - `flutter analyze` and `flutter test` pass, including a test that a multi-item collapse seeds the summed total.
## Approach
- Verified 2026-07-12: a scan opens the editor with the itemized override on, and the Itemized → Quick toggle collapses multiple entries by keeping the first and dropping the rest — so the receipt total is lost, which is why even-splitting a scan is impossible today.
- Smallest honest fix: make the existing editor-mode toggle collapse to the summed item total, with a brief notice that items merge into one amount. Optionally surface the choice earlier (e.g. on the scanner result sheet: "claim per item" vs "split evenly") if it falls out naturally — but the toggle fix alone satisfies the contract.
- Likely touchpoints: lib/pages/expenses/presentation/expense_detail.dart (mode toggle / collapse logic, currently near the editor-mode handler), lib/pages/expenses/presentation/receipt_scanner_sheet.dart (only if the early choice is added), lib/l10n/*.arb for the merge notice.
- Decisions / tradeoffs: sum-on-collapse applies to all multi-item collapses, not just scanned ones — one consistent rule ("Quick amount = total of what was listed") instead of a scan-only special case.
- Depends: —
- Parallel-with: — (touches the same editor file as itemized-expense-categories; pull sequentially)
- Blockers: —

status: done

## Evidence

Fix: `_onEditorModeChanged` (lib/pages/expenses/presentation/expense_detail.dart) now seeds
the Quick amount on Itemized → Quick collapse from `_itemizedTotalFromForm()` — the live sum
of every item line total — read *before* the extra entries are dropped, instead of keeping
only the first item's amount. When 2+ items collapse it fires a `showSnackBar` with the new
`editorModeCollapseNotice` string ("Items merged into one amount for an even split.", added to
app_en.arb + app_de.arb) so the loss is announced as it happens. Switching back to Itemized is
unchanged; scanned receipts still open itemized by default (`_scanReceipt` sets
`_itemizedOverride = true`), so per-item claiming remains the default after a scan.

How each acceptance criterion was proven:
- Even split without retyping, amount = receipt total: new test
  `collapsing a multi-item itemized expense to Quick seeds the summed total` builds a two-group
  expense (Beer €2.50 + Wine €4.00), toggles to Quick, and asserts the Quick amount reads `6.50`
  and `2.50` is gone — the summed total, not the first item's amount.
- Produces a normal quick expense: after collapse the test asserts the Quick footer CTA
  (`expenseAddButton`) is present — the standard quick-expense layout with equal shares.
- Collapse seeds the summed total: same test; the itemized header already reads
  `toCurrency(6.5)` before the toggle (proves the sum source), and Quick shows `6.50` after.
- User told before/as detail drops: same test asserts `editorModeCollapseNotice` snackbar is
  visible after the collapse.
- Scanned/itemized claiming unchanged & default after scan: existing F146 / itemized-category /
  "Quick toggle honored" tests still pass unchanged (20/20 in the editor suite).
- Gates: `flutter analyze` → "No issues found!"; `flutter test` → All tests passed (915),
  including the new collapse test.

Gate summary (`.ristretto.json`): format (dart format, 0 changed) ✓ · lint (flutter analyze,
no issues) ✓ · test (flutter test, 915 passed) ✓.
