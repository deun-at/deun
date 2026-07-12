import 'keypad_amount.dart';

/// The four arithmetic operators the amount keypad supports.
enum KeypadOperator {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const KeypadOperator(this.symbol);

  /// The glyph shown on the operator key and in the expression line.
  final String symbol;
}

/// Immutable calculator state layered on top of [KeypadAmount].
///
/// It keeps a physical-calculator, left-to-right chain: a folded [_pending]
/// accumulator, a [_operator] awaiting its right-hand operand, and the current
/// [_operand] (a [KeypadAmount], so operand typing reuses the exact single-dot /
/// 2-decimal / 7-integer-digit rules — and clamping — of the plain keypad).
///
/// Evaluation is plain arithmetic on doubles; the committed [value] is rounded
/// to 2 decimals so it obeys the same keypad rules and feeds the same save path
/// as a plainly typed amount. Divide-by-zero and >7-integer-digit overflow are
/// surfaced as [hasError] so the sheet can block the commit instead of crashing
/// or persisting a bad value.
class KeypadCalculator {
  const KeypadCalculator._(
    this._pending,
    this._operator,
    this._operand,
    this._awaitingOperand,
  );

  /// The folded left-hand value, or `null` when no operator is pending.
  final double? _pending;

  /// The operator awaiting its right-hand operand, or `null` for plain entry.
  final KeypadOperator? _operator;

  /// The operand currently being typed.
  final KeypadAmount _operand;

  /// True right after an operator press, before any operand digit/decimal —
  /// the operand shows as empty and the running result is just [_pending].
  final bool _awaitingOperand;

  /// Seeds a plain-entry calculator (no pending operation) from [text].
  factory KeypadCalculator.fromText(String? text) =>
      KeypadCalculator._(null, null, KeypadAmount.fromText(text), false);

  static final KeypadAmount _zero = KeypadAmount.fromText('0');

  KeypadCalculator _copy({
    double? pending,
    KeypadOperator? operator,
    KeypadAmount? operand,
    bool? awaitingOperand,
  }) {
    return KeypadCalculator._(
      pending ?? _pending,
      operator ?? _operator,
      operand ?? _operand,
      awaitingOperand ?? _awaitingOperand,
    );
  }

  /// Appends a digit to the current operand (starting a fresh operand if an
  /// operator was just pressed).
  KeypadCalculator appendDigit(String digit) {
    return _copy(operand: _operand.appendDigit(digit), awaitingOperand: false);
  }

  /// Adds a decimal point to the current operand.
  KeypadCalculator appendDecimal() {
    return _copy(operand: _operand.appendDecimal(), awaitingOperand: false);
  }

  /// Removes the last character of the current operand.
  KeypadCalculator backspace() {
    if (_awaitingOperand) return this;
    return _copy(operand: _operand.backspace());
  }

  /// Applies [op] physical-calculator style: resolves any pending operation
  /// first (left-to-right chaining), then holds [op] for the next operand.
  ///
  /// A no-op while the current result is invalid (e.g. `12 ÷ 0 +`), so the
  /// user must correct the operand before chaining further. Pressing an
  /// operator while one is already pending just swaps the operator.
  KeypadCalculator applyOperator(KeypadOperator op) {
    if (_operator == null) {
      return KeypadCalculator._(_operand.value, op, _zero, true);
    }
    if (_awaitingOperand) {
      return _copy(operator: op);
    }
    final folded = _combine(_pending!, _operator, _operand.value);
    if (folded == null) return this; // invalid (divide by zero): keep the error
    return KeypadCalculator._(folded, op, _zero, true);
  }

  static double? _combine(double a, KeypadOperator op, double b) {
    switch (op) {
      case KeypadOperator.add:
        return a + b;
      case KeypadOperator.subtract:
        return a - b;
      case KeypadOperator.multiply:
        return a * b;
      case KeypadOperator.divide:
        return b == 0 ? null : a / b;
    }
  }

  /// The raw running result, or `null` on divide-by-zero. While awaiting an
  /// operand the dangling operator is ignored (the result is just [_pending]).
  double? get _rawResult {
    if (_operator == null) return _operand.value;
    if (_awaitingOperand) return _pending;
    return _combine(_pending!, _operator, _operand.value);
  }

  /// The live running result rounded to 2 decimals, or `null` when invalid.
  double? get result {
    final raw = _rawResult;
    if (raw == null) return null;
    return double.parse(raw.toStringAsFixed(2));
  }

  /// True when there is a pending operator awaiting/using an operand, i.e. a
  /// calculation is in progress (drives whether the expression line shows).
  bool get hasPendingOperation => _operator != null;

  /// True when the current state cannot be committed: divide-by-zero, or a
  /// result that would exceed the keypad's 7-integer-digit limit.
  bool get hasError {
    final r = result;
    if (r == null) return true; // divide by zero
    return r.abs() >= 10000000; // more than 7 integer digits
  }

  /// The value to commit on confirm/=, rounded to 2 decimals. `0` when invalid
  /// (callers must gate on [hasError]).
  double get value => hasError ? 0 : result!;

  /// The in-progress expression line (folded left value + pending operator +
  /// current operand), or an empty string during plain entry.
  String get expression {
    if (_operator == null) return '';
    final left = _format(_pending!);
    if (_awaitingOperand) return '$left ${_operator.symbol}';
    return '$left ${_operator.symbol} ${_operand.text}';
  }

  static String _format(double v) {
    final fixed = v.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }
}
