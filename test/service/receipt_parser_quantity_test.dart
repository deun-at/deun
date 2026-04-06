import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/service/receipt_parser.dart';

void main() {
  group('ReceiptParser.extractQuantity', () {
    group('prefix patterns', () {
      test('3x Beer → ("Beer", 3)', () {
        expect(ReceiptParser.extractQuantity('3x Beer'), ('Beer', 3));
      });

      test('3X Beer → ("Beer", 3)', () {
        expect(ReceiptParser.extractQuantity('3X Beer'), ('Beer', 3));
      });

      test('2x Coca Cola → ("Coca Cola", 2)', () {
        expect(ReceiptParser.extractQuantity('2x Coca Cola'), ('Coca Cola', 2));
      });

      test('10x Item → ("Item", 10)', () {
        expect(ReceiptParser.extractQuantity('10x Item'), ('Item', 10));
      });
    });

    group('suffix patterns', () {
      test('Beer x3 → ("Beer", 3)', () {
        expect(ReceiptParser.extractQuantity('Beer x3'), ('Beer', 3));
      });

      test('Beer X3 → ("Beer", 3)', () {
        expect(ReceiptParser.extractQuantity('Beer X3'), ('Beer', 3));
      });

      test('Coca Cola x2 → ("Coca Cola", 2)', () {
        expect(ReceiptParser.extractQuantity('Coca Cola x2'), ('Coca Cola', 2));
      });
    });

    group('no quantity', () {
      test('Just Beer → ("Just Beer", 1)', () {
        expect(ReceiptParser.extractQuantity('Just Beer'), ('Just Beer', 1));
      });

      test('single word → (word, 1)', () {
        expect(ReceiptParser.extractQuantity('Milk'), ('Milk', 1));
      });
    });

    group('edge cases', () {
      test('short name after prefix ignored: 3x A → ("3x A", 1)', () {
        // cleanName < 2 chars → falls through
        expect(ReceiptParser.extractQuantity('3x A'), ('3x A', 1));
      });
    });
  });
}
