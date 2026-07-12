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

status: planned
