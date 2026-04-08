import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/service/receipt_parser.dart';

void main() {
  List<ReceiptLine> lines(List<String> texts, {double defaultHeight = 12}) {
    return texts
        .asMap()
        .entries
        .map((e) => ReceiptLine(
              text: e.value,
              top: e.key * 20.0,
              left: 0,
              right: 200,
              height: defaultHeight,
            ))
        .toList();
  }

  List<ReceiptLine> linesWithHeights(List<(String, double)> entries) {
    return entries
        .asMap()
        .entries
        .map((e) => ReceiptLine(
              text: e.value.$1,
              top: e.key * 20.0,
              left: 0,
              right: 200,
              height: e.value.$2,
            ))
        .toList();
  }

  group('isSkippable - metadata patterns', () {
    test('skips URLs', () {
      expect(ReceiptParser.isSkippable('www.billa.at'), isTrue);
      expect(ReceiptParser.isSkippable('https://rewe.de'), isTrue);
    });

    test('skips email addresses', () {
      expect(ReceiptParser.isSkippable('info@billa.at'), isTrue);
      expect(ReceiptParser.isSkippable('office@apotheke.at'), isTrue);
    });

    test('skips long barcode numbers', () {
      expect(ReceiptParser.isSkippable('12345678901234'), isTrue);
    });

    test('skips separator lines', () {
      expect(ReceiptParser.isSkippable('***************'), isTrue);
      expect(ReceiptParser.isSkippable('--------------'), isTrue);
      expect(ReceiptParser.isSkippable('=============='), isTrue);
    });

    test('skips Austrian receipt metadata', () {
      expect(ReceiptParser.isSkippable('Kassa 3'), isTrue);
      expect(ReceiptParser.isSkippable('Bon-Nr. 1234'), isTrue);
      expect(ReceiptParser.isSkippable('Filiale 0042'), isTrue);
      expect(ReceiptParser.isSkippable('Terminal 01'), isTrue);
      expect(ReceiptParser.isSkippable('ATU12345678'), isTrue);
    });

    test('skips payment lines', () {
      expect(ReceiptParser.isSkippable('Bankomat'), isTrue);
      expect(ReceiptParser.isSkippable('Kontaktlos'), isTrue);
      expect(ReceiptParser.isSkippable('Bezahlt 5.50'), isTrue);
      expect(ReceiptParser.isSkippable('KK Visa'), isTrue);
      expect(ReceiptParser.isSkippable('Bezahlung'), isTrue);
      expect(ReceiptParser.isSkippable('Contless'), isTrue);
      expect(ReceiptParser.isSkippable('BEZAHLWEISE'), isTrue);
    });

    test('skips date/time metadata lines', () {
      expect(ReceiptParser.isSkippable('Datum: 15.03.2026'), isTrue);
      expect(ReceiptParser.isSkippable('Zeit: 14:30'), isTrue);
      expect(ReceiptParser.isSkippable('Uhrzeit 10:00'), isTrue);
    });

    test('skips receipt tracking numbers', () {
      expect(ReceiptParser.isSkippable('Vr-Nr. 12345'), isTrue);
      expect(ReceiptParser.isSkippable('Trace-Nr. 67890'), isTrue);
      expect(ReceiptParser.isSkippable('AS-Proc-Code: 123'), isTrue);
      expect(ReceiptParser.isSkippable('Cap-Perf: 0000'), isTrue);
    });

    test('skips thank you / farewell lines', () {
      expect(ReceiptParser.isSkippable('Vielen Dank für Ihren Einkauf'), isTrue);
      expect(ReceiptParser.isSkippable('Danke für Ihren Einkauf'), isTrue);
      expect(ReceiptParser.isSkippable('Auf Wiedersehen'), isTrue);
    });

    test('skips Kassabon / Rechnung labels', () {
      expect(ReceiptParser.isSkippable('Kassabon'), isTrue);
      expect(ReceiptParser.isSkippable('RECHNUNG'), isTrue);
      expect(ReceiptParser.isSkippable('Rechnungsbetrag EUR'), isTrue);
    });

    test('skips card transaction details', () {
      expect(ReceiptParser.isSkippable('PAN seq: 01'), isTrue);
      expect(ReceiptParser.isSkippable('AID: A0000000031010'), isTrue);
      expect(ReceiptParser.isSkippable('MID: 1234567'), isTrue);
      expect(ReceiptParser.isSkippable('KIN/AKTUS'), isTrue);
    });

    test('skips VOLLER LEBEN slogan', () {
      expect(ReceiptParser.isSkippable('VOLLER LEBEN'), isTrue);
      expect(ReceiptParser.isSkippable('Voller Leben'), isTrue);
    });

    test('skips Kundenbeleg / Verkauf labels', () {
      expect(ReceiptParser.isSkippable('KUNDENBELEG'), isTrue);
      expect(ReceiptParser.isSkippable('VERKAUF'), isTrue);
    });

    test('does not skip normal item lines', () {
      expect(ReceiptParser.isSkippable('Vollmilch 1L'), isFalse);
      expect(ReceiptParser.isSkippable('Bio Bananen'), isFalse);
      expect(ReceiptParser.isSkippable('CLEVER RIESENMANELN ASD'), isFalse);
      expect(ReceiptParser.isSkippable('Sardinen Extra Sch'), isFalse);
    });
  });

  group('isPromoLabel', () {
    test('detects EXTREM AKTION', () {
      expect(ReceiptParser.isPromoLabel('EXTREM AKTION'), isTrue);
    });

    test('detects Mein Rabatt', () {
      expect(ReceiptParser.isPromoLabel('Mein Rabatt'), isTrue);
    });

    test('does not match normal items', () {
      expect(ReceiptParser.isPromoLabel('Vollmilch'), isFalse);
      expect(ReceiptParser.isPromoLabel('Bio Bananen'), isFalse);
    });
  });

  group('hasNegativeAmount', () {
    test('detects negative amounts', () {
      expect(ReceiptParser.hasNegativeAmount('-0.39'), isTrue);
      expect(ReceiptParser.hasNegativeAmount('-1.00'), isTrue);
      expect(ReceiptParser.hasNegativeAmount('Mein Rabatt -0.39'), isTrue);
    });

    test('does not match positive amounts', () {
      expect(ReceiptParser.hasNegativeAmount('3.50'), isFalse);
      expect(ReceiptParser.hasNegativeAmount('Milch 1.29'), isFalse);
    });
  });

  group('cleanItemName', () {
    test('strips single-letter tax codes', () {
      expect(ReceiptParser.cleanItemName('Karotten kernlos B'), 'Karotten kernlos');
      expect(ReceiptParser.cleanItemName('SanLucar Avocado essreif B'), 'SanLucar Avocado essreif');
    });

    test('strips two-letter tax codes', () {
      expect(ReceiptParser.cleanItemName('Cashewnüsse CI'), 'Cashewnüsse');
    });

    test('does not strip 3+ letter words (part of the name)', () {
      // CLA = "Classic" abbreviation, not a tax code
      expect(ReceiptParser.cleanItemName('WICK NASVIN CLA'), 'WICK NASVIN CLA');
    });

    test('strips trailing punctuation', () {
      expect(ReceiptParser.cleanItemName('Vollmilch ---'), 'Vollmilch');
      expect(ReceiptParser.cleanItemName('Brot .**'), 'Brot');
    });
  });

  group('estimateHeaderEnd', () {
    test('detects header end at first item with amount', () {
      final result = ReceiptParser.estimateHeaderEnd(lines([
        'BILLA',
        'Hauptstrasse 12',
        '1010 Wien',
        'Vollmilch 1.29',
        'Brot 2.49',
        'Summe 3.78',
      ]));
      expect(result, 3);
    });

    test('returns 0 when no item lines have amounts', () {
      final result = ReceiptParser.estimateHeaderEnd(lines([
        'BILLA',
        'Hauptstrasse 12',
        'Vollmilch',
        'Summe 1.29',
      ]));
      expect(result, 0);
    });
  });

  group('extractMerchantName - improved', () {
    test('prefers tallest line in header as store name', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('BILLA', 24.0),
        ('Hauptstrasse 12', 12.0),
        ('1010 Wien', 12.0),
        ('Vollmilch', 12.0),
      ]));
      expect(result, 'BILLA');
    });

    test('skips address lines with number prefix', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('12 Hauptstrasse', 12.0),
        ('SPAR', 14.0),
      ]));
      expect(result, 'SPAR');
    });

    test('skips postal code lines', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('1010 Wien', 12.0),
        ('HOFER', 14.0),
      ]));
      expect(result, 'HOFER');
    });

    test('skips URL lines', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('www.billa.at', 12.0),
        ('BILLA AG', 14.0),
      ]));
      expect(result, 'BILLA AG');
    });

    test('skips VOLLER LEBEN slogan', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('BILLA', 28.0),
        ('VOLLER LEBEN', 14.0),
        ('BILLA AG', 12.0),
      ]));
      expect(result, 'BILLA');
    });

    test('skips company type suffixes', () {
      final result = ReceiptParser.extractMerchantName(linesWithHeights([
        ('AG', 12.0),
        ('BILLA', 20.0),
      ]));
      expect(result, 'BILLA');
    });

    test('only looks at first 8 lines', () {
      final manyLines = linesWithHeights([
        ('Line 1', 10.0),
        ('Line 2', 10.0),
        ('Line 3', 10.0),
        ('Line 4', 10.0),
        ('Line 5', 10.0),
        ('Line 6', 10.0),
        ('Line 7', 10.0),
        ('Line 8', 10.0),
        ('ACTUAL STORE NAME', 30.0),
      ]);
      final result = ReceiptParser.extractMerchantName(manyLines);
      expect(result, isNot('ACTUAL STORE NAME'));
    });
  });

  group('full receipt simulation - BILLA', () {
    test('typical BILLA receipt', () {
      final receiptLines = linesWithHeights([
        ('BILLA', 28.0),
        ('VOLLER LEBEN', 14.0),
        ('BILLA AG', 10.0),
        ('PRATERSTRN', 10.0),
        ('ATU 18259097', 10.0),
        ('Datum: 17.03.2026 Zeit: 10:09', 10.0),
        ('EXTREM AKTION', 10.0),
        ('Karotten kernlos B 2.90', 10.0),
        ('CLEVER RIESENMANELN ASD B 3.99', 10.0),
        ('Sardinen Extra Sch B 2.99', 10.0),
        ('Clever Duftsteinchen Ocea 1.15', 10.0),
        ('Summe 16.54', 10.0),
        ('Gegeben KK Visa EUR', 10.0),
        ('Kontaktlos', 10.0),
        ('Bezahlung', 10.0),
        ('Vr-Nr. 12345', 10.0),
        ('Trace-Nr. 67890', 10.0),
      ]);

      final total = ReceiptParser.extractTotal(receiptLines);
      expect(total, 16.54);

      final merchant = ReceiptParser.extractMerchantName(receiptLines);
      expect(merchant, 'BILLA');

      final date = ReceiptParser.extractDate(receiptLines);
      expect(date, DateTime(2026, 3, 17));
    });

    test('BILLA with discounts', () {
      final receiptLines = linesWithHeights([
        ('BILLA', 28.0),
        ('VOLLER LEBEN', 14.0),
        ('Datum: 27.03.2026 Zeit: 21:10', 10.0),
        ('Choceur Dunkle Schokolade B 6.90', 10.0),
        ('Choceur MILCHSCHOKO ENER B 6.97', 10.0),
        ('Cashewnüsse CI 3.25', 10.0),
        ('Mein Rabatt -0.39', 10.0),
        ('Summe 23.72', 10.0),
      ]);

      final total = ReceiptParser.extractTotal(receiptLines);
      expect(total, 23.72);

      // Discount line should be skipped
      expect(ReceiptParser.isSkippable('Mein Rabatt -0.39'), isTrue);
    });
  });

  group('full receipt simulation - pharmacy', () {
    test('Apotheke receipt', () {
      final receiptLines = linesWithHeights([
        ('Apotheke zum römischen Kaiser', 16.0),
        ('Mag. pharm Claudia Westhäuser e.U.', 10.0),
        ('1010 Wien Weihburgg 13', 10.0),
        ('Tel 0043 1512 4418', 10.0),
        ('office@apotheke.at', 10.0),
        ('ATU/J96087', 10.0),
        ('RECHNUNG', 12.0),
        ('WICK NASVIN CLA.SF SPRO.05% 10ML 12.50', 10.0),
        ('Rechnungsbetrag EUR 12.50', 10.0),
        ('Umsatzsteuer 1.14', 10.0),
        ('MASTERCARD XXXX 1234', 10.0),
      ]);

      final merchant = ReceiptParser.extractMerchantName(receiptLines);
      expect(merchant, 'Apotheke zum römischen Kaiser');
    });
  });

  group('full receipt simulation - Müller', () {
    test('Müller receipt with ZU ZAHLEN total', () {
      final receiptLines = linesWithHeights([
        ('Müller', 24.0),
        ('KUNDENBELEG', 10.0),
        ('SK ARTL 3.99', 10.0),
        ('ORIS KOMPLETTLE CI 3.99', 10.0),
        ('Rabatt -1.00', 10.0),
        ('ZU ZAHLEN 3.99', 10.0),
        ('MwST 10% 0.36', 10.0),
        ('Brutto 3.99', 10.0),
      ]);

      final merchant = ReceiptParser.extractMerchantName(receiptLines);
      expect(merchant, 'Müller');

      // "ZU ZAHLEN" should be recognized as total
      expect(ReceiptParser.isSkippable('ZU ZAHLEN 3.99'), isTrue);

      // Rabatt line should be skipped
      expect(ReceiptParser.isSkippable('Rabatt -1.00'), isTrue);
    });
  });

  group('full receipt simulation - ACTION', () {
    test('ACTION receipt', () {
      final receiptLines = linesWithHeights([
        ('///ACTION', 20.0),
        ('7095 Wien Landstr.', 10.0),
        ('ANr0102', 10.0),
        ('Kassa 3 Bon-Nr. 456', 10.0),
        ('BEZAHLWEISE', 10.0),
        ('Kontaktlos', 10.0),
        ('Globalbonus', 10.0),
      ]);

      final merchant = ReceiptParser.extractMerchantName(receiptLines);
      expect(merchant, '///ACTION');

      // All metadata should be skippable
      expect(ReceiptParser.isSkippable('BEZAHLWEISE'), isTrue);
      expect(ReceiptParser.isSkippable('Globalbonus'), isTrue);
    });
  });
}
