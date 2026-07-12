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

status: done

## Evidence

Pure model `lib/pages/expenses/data/keypad_calculator.dart` (`KeypadCalculator`,
built on the existing `KeypadAmount` for per-operand normalize/clamp) drives the
sheet; the sheet returns the same `double` on the unchanged save path.

Each criterion proven by a test (all green):

- **+ − × ÷ present, `12.50 + 3.20 + 8 = 23.70`** — model test `chaining 12.50 + 3.20 + 8 confirms as 23.70`; widget test `offers the four operators and chains 12.50 + 3.20 + 8 = 23.70` (asserts the four `keypad_op_*` keys exist and the confirmed pop is `23.70`).
- **In-progress expression + live running result** — model tests `expression line ...` (`'12.50 +'`, `'12.50 + 3'`); widget test `shows the in-progress expression line while typing` reads the `keypad_expression` Text. The big `MoneyText` shows `_calc.value` (live folded result).
- **Left-to-right chaining, confirm = "="** — model tests `operators resolve left-to-right (no precedence): 2 + 3 * 4 = 20`, `pressing an operator twice just swaps the operator`, `confirming with a dangling operator commits the left value`.
- **Committed result obeys keypad rules (2 dp / 7 int digits), same value path** — model tests `division rounds ... to 2 decimals (10 / 3 = 3.33)`, `multiplication result is rounded to 2 decimals`, `each operand still enforces the 2-decimal keypad limit`; `>7 integer digits` result flagged as error (below). Result rounded via `toStringAsFixed(2)`; sheet still returns a `double` → `toStringAsFixed(2)` at each call site (unchanged).
- **Divide-by-zero / invalid never crash or commit** — model tests `division by zero is an error and cannot be committed`, `a result exceeding 7 integer digits is an error`, `correcting the divisor clears the error`; widget test `division by zero blocks the confirm and shows an error` (inline `amountKeypadInvalid` shown, confirm disabled → sheet stays open, no value popped).
- **Negative final result handled as today** — model test `a negative final result is committed as-is (5 - 8 = -3)`; the sheet returns `-3.0` down the same path (itemized validator already allows negatives; total guard unchanged) — no negative-handling code added here.
- **Plain amount unchanged** — model tests `behaves like the plain keypad: value is the typed amount`, `expression line is empty during plain entry`; existing `AmountKeypadSheet` widget tests (build/confirm, 2-decimal limit, backspace, seed) still pass unmodified.
- **Pure logic + unit tests** — `test/model/keypad_calculator_test.dart` (16 tests), mirroring `test/model/keypad_amount_test.dart`.

### Gate summary (`.ristretto.json`)
- `dart format` — 4 files, 0 changed.
- `flutter analyze` — No issues found.
- `flutter test` — All tests passed (946), including 16 model + 4 new widget tests.
