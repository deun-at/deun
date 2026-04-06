import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/service/receipt_parser.dart';

void main() {
  group('ReceiptParser.parseAmount', () {
    group('German format (comma as decimal)', () {
      test('simple amount: 12,50 → 12.5', () {
        expect(ReceiptParser.parseAmount('12,50'), 12.5);
      });

      test('thousands separator: 1.234,56 → 1234.56', () {
        expect(ReceiptParser.parseAmount('1.234,56'), 1234.56);
      });

      test('large amount: 12.345,67 → 12345.67', () {
        expect(ReceiptParser.parseAmount('12.345,67'), 12345.67);
      });

      test('one euro: 1,00 → 1.0', () {
        expect(ReceiptParser.parseAmount('1,00'), 1.0);
      });
    });

    group('English format (period as decimal)', () {
      test('simple amount: 12.50 → 12.5', () {
        expect(ReceiptParser.parseAmount('12.50'), 12.5);
      });

      test('thousands separator: 1,234.56 → 1234.56', () {
        expect(ReceiptParser.parseAmount('1,234.56'), 1234.56);
      });

      test('large amount: 12,345.67 → 12345.67', () {
        expect(ReceiptParser.parseAmount('12,345.67'), 12345.67);
      });
    });

    group('currency symbols stripped', () {
      test('euro prefix: €12,50 → 12.5', () {
        expect(ReceiptParser.parseAmount('€12,50'), 12.5);
      });

      test('euro with space: € 12,50 → 12.5', () {
        expect(ReceiptParser.parseAmount('€ 12,50'), 12.5);
      });

      test('dollar prefix: \$12.50 → 12.5', () {
        expect(ReceiptParser.parseAmount('\$12.50'), 12.5);
      });
    });

    group('edge cases', () {
      test('integer: 12 → 12.0', () {
        expect(ReceiptParser.parseAmount('12'), 12.0);
      });

      test('empty string → null', () {
        expect(ReceiptParser.parseAmount(''), isNull);
      });

      test('non-numeric → null', () {
        expect(ReceiptParser.parseAmount('abc'), isNull);
      });

      test('zero: 0,00 → 0.0', () {
        expect(ReceiptParser.parseAmount('0,00'), 0.0);
      });

      test('no separator: 100 → 100.0', () {
        expect(ReceiptParser.parseAmount('100'), 100.0);
      });
    });
  });
}
