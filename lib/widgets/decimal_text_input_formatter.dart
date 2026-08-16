import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Restricts a text field to a decimal number with at most [decimalRange]
/// fractional digits, normalizing a typed `,` to `.`.
///
/// NOT a money formatter: amount entry in this app is keypad-only (every amount
/// field opens `AmountKeypadSheet`, which takes its precision from the group's
/// [Currency]), so the only field wired to this is the per-member percentage
/// input. It is kept general — `decimalRange: 0` rejects the separator outright
/// — but it deliberately has no currency constructor, because a currency-shaped
/// entry point with no caller is just an untested claim.
class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({this.decimalRange})
    : assert(decimalRange == null || decimalRange >= 0);

  /// Fractional digits accepted. 0 rejects the decimal point outright.
  final int? decimalRange;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    TextSelection newSelection = newValue.selection.copyWith();
    String truncated = newValue.text;

    if (decimalRange != null) {
      String value = newValue.text;
      int baseOffset = newValue.selection.baseOffset;

      if (baseOffset > 0) {
        String? typedCharacter = value.characters.elementAtOrNull(
          baseOffset - 1,
        );
        int typedCharacterInt = typedCharacter?.codeUnitAt(0) ?? 0;

        if (typedCharacterInt >= 48 && typedCharacterInt <= 57) {
          //0-9 is okay, do nothing
        } else if (typedCharacterInt == 44) {
          //,
          if (decimalRange == 0) {
            // No fractional digits accepted: reject the separator outright.
            truncated = oldValue.text;
            newSelection = oldValue.selection.copyWith();
          } else {
            truncated = truncated.replaceAll(RegExp(r'(,)'), '.');
            if (isDoubleDot(truncated)) {
              truncated = oldValue.text;
              newSelection = oldValue.selection.copyWith();
            }
          }
        } else if (typedCharacterInt == 46) {
          //.
          if (decimalRange == 0 || isDoubleDot(truncated)) {
            truncated = oldValue.text;
            newSelection = oldValue.selection.copyWith();
          }
        } else {
          //everything else is not allowed
          truncated = oldValue.text;
          newSelection = oldValue.selection.copyWith();
        }
      }

      int dotIndex = truncated.indexOf('.');
      if (dotIndex >= 0 && dotIndex + decimalRange! + 1 < truncated.length) {
        truncated = oldValue.text;
        newSelection = oldValue.selection.copyWith();
      }
    } else {
      newSelection = newValue.selection;
    }

    if (truncated.indexOf('0') == 0 &&
        truncated.length > 1 &&
        truncated.indexOf('.') != 1) {
      truncated = truncated.replaceAll(RegExp(r'^0'), '');
      newSelection = TextSelection.collapsed(offset: truncated.length);
    }

    if (truncated == '') {
      truncated = '0';
      newSelection = const TextSelection.collapsed(offset: 1);
    }

    return TextEditingValue(
      text: truncated,
      selection: newSelection,
      composing: TextRange.empty,
    );
  }

  bool isDoubleDot(String value) {
    final List<String> nums = value.split('.');
    return nums.length > 2;
  }
}
