# keypad-calculator — Calculator in the amount keypad sheet

## Spec
- Source: idea ("calculator in the amount bottom sheet", 2026-07-12 planning session)
- Flight: —
- Goal: The amount keypad sheet can add, subtract, multiply and divide, so amounts like "my part plus the rest of the receipt" are computed in place instead of in a separate calculator app.
- Acceptance:
  - The keypad sheet offers +, −, ×, ÷ alongside the digits; typing `12.50 + 3.20 + 8` then confirming yields an amount of 23.70.
  - The sheet shows the in-progress expression (or pending operand + operator) and a live running result while typing, so the user always sees what will be committed.
  - Operators chain left-to-right (each operator press resolves the pending operation, physical-calculator style); pressing confirm/= resolves the final result.
  - The committed result obeys the existing keypad rules — max 2 decimal places, max 7 integer digits — and feeds the exact same value path as a plainly typed amount (save path and validators unchanged).
  - Division by zero and other invalid states never crash or commit: the sheet blocks the confirm or shows an inline error until the expression is corrected.
  - A negative final result is handled the same way the app handles negative amounts entered today (the recent "allow negative item" behavior is not regressed).
  - Entering a plain amount with no operators behaves exactly as before.
  - Expression/evaluation logic lives in pure code with unit tests (chaining, decimals, clamping, divide-by-zero), mirroring how the current keypad model is tested.
  - `flutter analyze` and `flutter test` pass.
## Approach
- Extend the existing pure keypad model (currently a normalize-and-clamp string model) with a small calculator state: pending value, pending operator, current operand. Evaluation is plain arithmetic on doubles rounded to 2 decimals at commit — no expression-parser dependency needed for left-to-right semantics.
- UI: add an operator column/row to the existing keypad sheet layout; keep the sheet's current look (it's a liked, established control — this augments, not redesigns).
- Likely touchpoints: lib/pages/expenses/data/keypad_amount.dart (or a sibling pure model), lib/widgets/restyle/expense_picker_sheets.dart (keypad sheet UI), lib/pages/expenses/presentation/expense_entry_widget.dart, existing keypad tests as the pattern.
- Decisions / tradeoffs: left-to-right chaining over operator precedence — matches what a physical calculator and every amount-pad-with-calculator (banking apps) does, and precedence surprises nobody entering receipt sums. Percent, memory keys, and parentheses are out of scope.
- Depends: —
- Parallel-with: —
- Blockers: —

status: planned
