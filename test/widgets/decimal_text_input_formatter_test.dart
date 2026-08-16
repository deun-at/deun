import 'package:deun/widgets/decimal_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _v(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

String _type(DecimalTextInputFormatter f, String from, String to) =>
    f.formatEditUpdate(_v(from), _v(to)).text;

void main() {
  // multi-currency-core: this formatter is NOT the money entry path — every
  // amount field opens the keypad sheet, whose precision comes from the group's
  // Currency (see keypad_amount_test / keypad_calculator_test). Its only wiring
  // in lib/ is the per-member percentage field, so it is tested as the general
  // decimal-range formatter it actually is, with no currency constructor.
  group('DecimalTextInputFormatter honours decimalRange', () {
    test('decimalRange: 0 rejects both separators outright', () {
      final f = DecimalTextInputFormatter(decimalRange: 0);
      expect(_type(f, '12', '12.'), '12');
      expect(_type(f, '12', '12,'), '12');
      expect(_type(f, '12', '123'), '123');
    });

    test('decimalRange: 1 blocks a second fractional digit', () {
      // Regression: the old body hardcoded `dotIndex + 3`, so decimalRange: 1
      // still let two fractional digits through — the live wiring in
      // expense_entry_widget.dart's percentage field.
      final f = DecimalTextInputFormatter(decimalRange: 1);
      expect(_type(f, '12.5', '12.55'), '12.5');
      expect(_type(f, '12', '12.'), '12.');
      expect(_type(f, '12.', '12.5'), '12.5');
    });

    test(
      'decimalRange: 2 accepts two fractional digits and blocks a third',
      () {
        final f = DecimalTextInputFormatter(decimalRange: 2);
        expect(_type(f, '12', '12.'), '12.');
        expect(_type(f, '12.5', '12.50'), '12.50');
        expect(_type(f, '12.50', '12.509'), '12.50');
      },
    );

    test('a typed comma is normalized to a dot', () {
      final f = DecimalTextInputFormatter(decimalRange: 2);
      expect(_type(f, '12', '12,'), '12.');
    });

    test('a second separator is rejected', () {
      final f = DecimalTextInputFormatter(decimalRange: 2);
      expect(_type(f, '12.5', '12.5.'), '12.5');
      expect(_type(f, '12.5', '12.5,'), '12.5');
    });
  });
}
