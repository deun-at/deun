import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/service/receipt_parser.dart';

void main() {
  group('ReceiptParser.extractDate', () {
    List<ReceiptLine> lines(List<String> texts) {
      return texts.asMap().entries.map((e) => ReceiptLine.simple(e.value, e.key * 10.0)).toList();
    }

    group('DD.MM.YYYY format', () {
      test('parses 15.03.2024', () {
        final result = ReceiptParser.extractDate(lines(['15.03.2024']));
        expect(result, DateTime(2024, 3, 15));
      });

      test('parses 01.01.2023', () {
        final result = ReceiptParser.extractDate(lines(['01.01.2023']));
        expect(result, DateTime(2023, 1, 1));
      });
    });

    group('DD.MM.YY format', () {
      test('parses 15.03.24', () {
        final result = ReceiptParser.extractDate(lines(['15.03.24']));
        expect(result, DateTime(2024, 3, 15));
      });

      test('parses 01.12.23', () {
        final result = ReceiptParser.extractDate(lines(['01.12.23']));
        expect(result, DateTime(2023, 12, 1));
      });
    });

    group('YYYY-MM-DD format', () {
      test('parses 2024-03-15', () {
        final result = ReceiptParser.extractDate(lines(['2024-03-15']));
        expect(result, DateTime(2024, 3, 15));
      });
    });

    group('DD/MM/YYYY format', () {
      test('parses 15/03/2024', () {
        final result = ReceiptParser.extractDate(lines(['15/03/2024']));
        expect(result, DateTime(2024, 3, 15));
      });
    });

    group('date mixed with text', () {
      test('extracts date from "Date: 15.03.2024 14:30"', () {
        final result = ReceiptParser.extractDate(lines(['Date: 15.03.2024 14:30']));
        expect(result, DateTime(2024, 3, 15));
      });
    });

    group('validation', () {
      test('pre-2020 date returns null', () {
        final result = ReceiptParser.extractDate(lines(['15.03.2019']));
        expect(result, isNull);
      });

      test('future date returns null', () {
        final futureYear = DateTime.now().year + 2;
        final result = ReceiptParser.extractDate(lines(['15.03.$futureYear']));
        expect(result, isNull);
      });

      test('no date in lines returns null', () {
        final result = ReceiptParser.extractDate(lines(['REWE Supermarket', 'Milk 3.50']));
        expect(result, isNull);
      });

      test('returns first valid date from multiple lines', () {
        final result = ReceiptParser.extractDate(lines([
          'REWE Supermarket',
          '15.03.2024 14:30',
          '16.03.2024',
        ]));
        expect(result, DateTime(2024, 3, 15));
      });
    });
  });
}
