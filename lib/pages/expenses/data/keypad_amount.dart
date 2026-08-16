/// Immutable model for the amount-keypad sheet.
///
/// Holds the in-progress amount as a normalized string and applies the keypad
/// edit rules — single decimal point, **2 decimal places**, **7 integer
/// digits** — entirely in pure code so the limits can be unit-tested without a
/// widget. The resulting [value] is the same `double` the inline editor wrote,
/// so the save path and validators are unchanged.
class KeypadAmount {
  const KeypadAmount._(this.text, this.decimalDigits);

  /// The normalized display string (e.g. `0`, `5.`, `12.50`).
  final String text;

  /// Fractional digits this amount accepts — the entry currency's
  /// [Currency.decimalDigits]. 0 means the decimal key is inert.
  final int decimalDigits;

  static const int maxIntegerDigits = 7;

  /// Builds a normalized [KeypadAmount] from arbitrary [input], clamping it to
  /// the integer/decimal-digit limits and collapsing empties to `0`.
  factory KeypadAmount.fromText(String? input, {int decimalDigits = 2}) {
    final raw = (input ?? '').trim();
    if (raw.isEmpty) return KeypadAmount._('0', decimalDigits);

    final firstDot = raw.indexOf('.');
    String intPart;
    String? decPart;
    if (firstDot >= 0) {
      intPart = raw.substring(0, firstDot);
      // Drop any additional dots from the decimal part.
      decPart = raw.substring(firstDot + 1).replaceAll('.', '');
    } else {
      intPart = raw;
    }

    // Keep digits only.
    intPart = intPart.replaceAll(RegExp(r'[^0-9]'), '');
    decPart = decPart?.replaceAll(RegExp(r'[^0-9]'), '');

    // Strip leading zeros from the integer part, but keep a single zero.
    intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
    if (intPart.isEmpty) intPart = '0';

    // Apply limits.
    if (intPart.length > maxIntegerDigits) {
      intPart = intPart.substring(0, maxIntegerDigits);
    }
    if (decimalDigits == 0) {
      decPart = null;
    } else if (decPart != null && decPart.length > decimalDigits) {
      decPart = decPart.substring(0, decimalDigits);
    }

    final normalized = decPart == null ? intPart : '$intPart.$decPart';
    return KeypadAmount._(normalized, decimalDigits);
  }

  bool get _hasDecimal => text.contains('.');

  String get _integerPart =>
      _hasDecimal ? text.substring(0, text.indexOf('.')) : text;

  String get _decimalPart =>
      _hasDecimal ? text.substring(text.indexOf('.') + 1) : '';

  /// Appends a single [digit] (`'0'`–`'9'`), enforcing the digit limits.
  /// Non-digit input is ignored.
  KeypadAmount appendDigit(String digit) {
    if (digit.length != 1 || !RegExp(r'^[0-9]$').hasMatch(digit)) return this;

    if (_hasDecimal) {
      if (_decimalPart.length >= decimalDigits) return this;
      return KeypadAmount._('$text$digit', decimalDigits);
    }

    // Integer part: replace a lone leading zero, else append within the limit.
    if (text == '0') return KeypadAmount._(digit, decimalDigits);
    if (_integerPart.length >= maxIntegerDigits) return this;
    return KeypadAmount._('$text$digit', decimalDigits);
  }

  /// Adds a single decimal point. No-op if one already exists, or if this
  /// currency has no fractional digits.
  KeypadAmount appendDecimal() {
    if (decimalDigits == 0 || _hasDecimal) return this;
    return KeypadAmount._('$text.', decimalDigits);
  }

  /// Removes the last character, collapsing to `0` when emptied.
  KeypadAmount backspace() {
    if (text.length <= 1) return KeypadAmount._('0', decimalDigits);
    final next = text.substring(0, text.length - 1);
    if (next.isEmpty || next == '') return KeypadAmount._('0', decimalDigits);
    return KeypadAmount._(next, decimalDigits);
  }

  /// The numeric value (a trailing point is treated as the integer value).
  double get value => double.tryParse(text.replaceAll(RegExp(r'\.$'), '')) ?? 0;

  /// Renders [value] the way the keypad writes it: fixed to [decimalDigits],
  /// but with an all-zero fractional part dropped (42.00 -> "42", 12.50 stays
  /// "12.50", and a 0-decimal currency never grows a point).
  ///
  /// THE keypad number format — the calculator's expression line, its
  /// backspace-restored operand and the sheet's seed text all go through here,
  /// so they cannot disagree about how many digits a currency shows.
  static String format(double value, int decimalDigits) {
    final fixed = value.toStringAsFixed(decimalDigits);
    if (decimalDigits == 0) return fixed;
    return fixed.endsWith('.${'0' * decimalDigits}')
        ? fixed.substring(0, fixed.length - (decimalDigits + 1))
        : fixed;
  }
}
