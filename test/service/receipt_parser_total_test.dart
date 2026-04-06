import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/service/receipt_parser.dart';

void main() {
  List<(String, double)> lines(List<String> texts) {
    return texts.asMap().entries.map((e) => (e.value, e.key * 10.0)).toList();
  }

  group('ReceiptParser.extractTotal', () {
    group('keyword matching', () {
      test('finds total on same line', () {
        final result = ReceiptParser.extractTotal(lines([
          'Milk 3.50',
          'Bread 2.00',
          'Total 5.50',
        ]));
        expect(result, 5.5);
      });

      test('finds Summe (German)', () {
        final result = ReceiptParser.extractTotal(lines([
          'Milch 3.50',
          'Brot 2.00',
          'Summe 5.50',
        ]));
        expect(result, 5.5);
      });

      test('finds Gesamt (German)', () {
        final result = ReceiptParser.extractTotal(lines([
          'Milch 3.50',
          'Gesamtbetrag 5.50',
        ]));
        expect(result, 5.5);
      });

      test('finds amount on next line after keyword', () {
        final result = ReceiptParser.extractTotal(lines([
          'Milk 3.50',
          'Total',
          '5.50',
        ]));
        expect(result, 5.5);
      });
    });

    group('fallback to largest amount', () {
      test('no keyword → returns largest amount', () {
        final result = ReceiptParser.extractTotal(lines([
          'Milk 3.50',
          'Bread 2.00',
          '5.50',
        ]));
        expect(result, 5.5);
      });

      test('no amounts at all → returns null', () {
        final result = ReceiptParser.extractTotal(lines([
          'REWE Supermarket',
          'Thank you!',
        ]));
        expect(result, isNull);
      });
    });
  });

  group('ReceiptParser.extractMerchantName', () {
    test('returns first non-amount, non-date line', () {
      final result = ReceiptParser.extractMerchantName(lines([
        'REWE Supermarket',
        '15.03.2024',
        'Milk 3.50',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('skips lines with amounts', () {
      final result = ReceiptParser.extractMerchantName(lines([
        '3.50',
        'REWE Supermarket',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('skips date lines', () {
      final result = ReceiptParser.extractMerchantName(lines([
        '15.03.2024',
        'REWE Supermarket',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('skips short lines', () {
      final result = ReceiptParser.extractMerchantName(lines([
        'AB',
        'REWE Supermarket',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('skips pure number lines', () {
      final result = ReceiptParser.extractMerchantName(lines([
        '0800 123 456',
        'REWE Supermarket',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('skips total keyword lines', () {
      final result = ReceiptParser.extractMerchantName(lines([
        'Total',
        'REWE Supermarket',
      ]));
      expect(result, 'REWE Supermarket');
    });

    test('returns null for empty list', () {
      final result = ReceiptParser.extractMerchantName([]);
      expect(result, isNull);
    });

    test('returns null when all lines are filtered', () {
      final result = ReceiptParser.extractMerchantName(lines([
        '3.50',
        '15.03.2024',
        'AB',
      ]));
      expect(result, isNull);
    });
  });

  group('ReceiptParser.isAmountOnly', () {
    test('"3.50" is amount only', () {
      expect(ReceiptParser.isAmountOnly('3.50'), isTrue);
    });

    test('"€ 3.50" is amount only', () {
      expect(ReceiptParser.isAmountOnly('€ 3.50'), isTrue);
    });

    test('"Milk 3.50" is NOT amount only', () {
      expect(ReceiptParser.isAmountOnly('Milk 3.50'), isFalse);
    });
  });

  group('ReceiptParser.isSkippable', () {
    test('line with exclusion keyword is skippable', () {
      expect(ReceiptParser.isSkippable('MwSt 19%'), isTrue);
    });

    test('line with total keyword is skippable', () {
      expect(ReceiptParser.isSkippable('TOTAL'), isTrue);
    });

    test('line with date is skippable', () {
      expect(ReceiptParser.isSkippable('15.03.2024'), isTrue);
    });

    test('normal line is not skippable', () {
      expect(ReceiptParser.isSkippable('Milk'), isFalse);
    });

    test('line with visa keyword is skippable', () {
      expect(ReceiptParser.isSkippable('VISA **** 1234'), isTrue);
    });
  });
}
