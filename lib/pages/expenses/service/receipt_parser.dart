import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/receipt_scan_result.dart';

class ReceiptParser {
  static final _exclusionKeywords = [
    'mwst', 'ust', 'tax', 'steuer', 'rabatt', 'discount',
    'bar', 'visa', 'mastercard', 'ec', 'karte', 'card',
    'gegeben', 'wechselgeld', 'change', 'rückgeld',
    'zwischensumme', 'subtotal', 'netto',
  ];

  static final _totalKeywords = [
    'total', 'sum', 'summe', 'gesamt', 'gesamtbetrag',
    'zu zahlen', 'betrag', 'endbetrag', 'amount due',
    'grand total', 'brutto',
  ];

  // Matches amounts like: 12.50, 12,50, 1.234,56, 1,234.56, €12.50
  static final _amountRegex = RegExp(
    r'[\€\$]?\s*(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[\€\$]?'
  );

  static final _datePatterns = [
    // DD.MM.YYYY
    RegExp(r'(\d{2})\.(\d{2})\.(\d{4})'),
    // DD.MM.YY
    RegExp(r'(\d{2})\.(\d{2})\.(\d{2})\b'),
    // YYYY-MM-DD
    RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
    // DD/MM/YYYY
    RegExp(r'(\d{2})/(\d{2})/(\d{4})'),
  ];

  static ReceiptScanResult parse(List<TextBlock> blocks) {
    final lines = _extractSortedLines(blocks);

    final date = _extractDate(lines);
    final total = _extractTotal(lines);
    final lineItems = _extractLineItems(lines, total);
    final merchantName = _extractMerchantName(lines);

    return ReceiptScanResult(
      merchantName: merchantName,
      date: date,
      lineItems: lineItems,
      total: total,
    );
  }

  static List<(String text, double top)> _extractSortedLines(List<TextBlock> blocks) {
    final lines = <(String text, double top)>[];
    for (final block in blocks) {
      for (final line in block.lines) {
        final top = line.boundingBox.top;
        lines.add((line.text.trim(), top));
      }
    }
    lines.sort((a, b) => a.$2.compareTo(b.$2));
    return lines;
  }

  static DateTime? _extractDate(List<(String, double)> lines) {
    final now = DateTime.now();

    for (final (text, _) in lines) {
      for (int i = 0; i < _datePatterns.length; i++) {
        final match = _datePatterns[i].firstMatch(text);
        if (match == null) continue;

        DateTime? candidate;
        try {
          switch (i) {
            case 0: // DD.MM.YYYY
              candidate = DateTime(
                int.parse(match.group(3)!),
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
              break;
            case 1: // DD.MM.YY
              candidate = DateTime(
                2000 + int.parse(match.group(3)!),
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
              break;
            case 2: // YYYY-MM-DD
              candidate = DateTime(
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
                int.parse(match.group(3)!),
              );
              break;
            case 3: // DD/MM/YYYY
              candidate = DateTime(
                int.parse(match.group(3)!),
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
              break;
          }
        } catch (_) {
          continue;
        }

        if (candidate != null &&
            !candidate.isAfter(now) &&
            candidate.isAfter(DateTime(2020))) {
          return candidate;
        }
      }
    }
    return null;
  }

  static double? _parseAmount(String amountStr) {
    // Determine decimal separator
    // If last separator is comma with 2 digits after → comma is decimal (German)
    // If last separator is period with 2 digits after → period is decimal (English)
    final cleaned = amountStr.replaceAll(RegExp(r'[\€\$\s]'), '');

    final lastComma = cleaned.lastIndexOf(',');
    final lastPeriod = cleaned.lastIndexOf('.');

    String normalized;
    if (lastComma > lastPeriod) {
      // Comma is decimal separator (German: 1.234,56)
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastPeriod > lastComma) {
      // Period is decimal separator (English: 1,234.56)
      normalized = cleaned.replaceAll(',', '');
    } else {
      normalized = cleaned;
    }

    return double.tryParse(normalized);
  }

  /// Extract amount from a line, returns null if no amount found.
  static double? _lineAmount(String text) {
    final matches = _amountRegex.allMatches(text);
    if (matches.isEmpty) return null;
    return _parseAmount(matches.last.group(1)!);
  }

  /// Check if a line is "amount-only" (just a number, no meaningful text).
  static bool _isAmountOnly(String text) {
    final stripped = text.replaceAll(_amountRegex, '').replaceAll(RegExp(r'[\s\€\$\dx]'), '').trim();
    return stripped.isEmpty || stripped.length <= 2;
  }

  /// Check if a line should be skipped entirely.
  static bool _isSkippable(String text) {
    final lower = text.toLowerCase();
    if (_exclusionKeywords.any((kw) => lower.contains(kw))) return true;
    if (_totalKeywords.any((kw) => lower.contains(kw))) return true;
    if (_datePatterns.any((p) => p.hasMatch(text))) return true;
    return false;
  }

  /// Extract total by looking for total keywords, then finding the amount
  /// on the same line or the next line with an amount.
  static double? _extractTotal(List<(String, double)> lines) {
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].$1.toLowerCase();
      if (!_totalKeywords.any((kw) => lower.contains(kw))) continue;

      // Check if this line itself has an amount
      final amount = _lineAmount(lines[i].$1);
      if (amount != null && amount > 0) return amount;

      // Look at the next few lines for the amount
      for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
        final nextAmount = _lineAmount(lines[j].$1);
        if (nextAmount != null && nextAmount > 0) return nextAmount;
      }
    }

    // Fallback: largest amount on the receipt
    double max = 0;
    for (final (text, _) in lines) {
      final amount = _lineAmount(text);
      if (amount != null && amount > max) max = amount;
    }
    return max > 0 ? max : null;
  }

  /// Extract line items by pairing text lines with their amounts.
  /// Handles two patterns:
  /// 1. Name and amount on the SAME line: "Milk 3.50"
  /// 2. Name on one line, amount on the NEXT line(s): "Milk" → "3.50"
  static List<ReceiptLineItem> _extractLineItems(
      List<(String, double)> lines, double? total) {
    final items = <ReceiptLineItem>[];

    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].$1;
      if (_isSkippable(text)) continue;

      final amount = _lineAmount(text);

      if (amount != null && amount > 0) {
        // Pattern 1: amount is on this line
        if (!_isAmountOnly(text)) {
          // Has both name and amount on the same line
          final amountMatch = _amountRegex.firstMatch(text);
          String name = text;
          if (amountMatch != null) {
            name = text.substring(0, amountMatch.start).trim();
          }
          name = name.replaceAll(RegExp(r'[\s\.\,\-\*]+$'), '').trim();

          if (name.length >= 3 && amount != total) {
            items.add(ReceiptLineItem(name: name, amount: amount));
          }
        }
        // If amount-only line, skip (it belongs to a previous name line,
        // already handled in pattern 2, or it's a total/duplicate)
      } else {
        // Pattern 2: this line has no amount — look ahead for the price
        if (text.length < 3) continue;
        // Skip lines that look like addresses, codes, etc.
        if (RegExp(r'^\d[\d\s\-\+\/\.]*$').hasMatch(text)) continue;

        // Look ahead for the next amount-only line
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextText = lines[j].$1;
          final nextAmount = _lineAmount(nextText);
          if (nextAmount != null && nextAmount > 0 && _isAmountOnly(nextText)) {
            if (nextAmount != total) {
              items.add(ReceiptLineItem(name: text, amount: nextAmount));
            }
            break;
          }
          // Stop looking if we hit another text line (not amount-only)
          if (!_isAmountOnly(nextText) && nextText.length >= 3) break;
        }
      }
    }
    return items;
  }

  static String? _extractMerchantName(List<(String, double)> lines) {
    for (final (text, _) in lines) {
      if (text.isEmpty || text.length < 3) continue;

      // Skip lines with amounts
      if (_amountRegex.hasMatch(text)) continue;

      // Skip lines that are dates
      if (_datePatterns.any((p) => p.hasMatch(text))) continue;

      // Skip lines with total/exclusion keywords
      final lower = text.toLowerCase();
      if (_totalKeywords.any((kw) => lower.contains(kw))) continue;
      if (_exclusionKeywords.any((kw) => lower.contains(kw))) continue;

      // Skip lines that are just numbers (phone, address numbers, etc.)
      if (RegExp(r'^\d[\d\s\-\+\/\.]*$').hasMatch(text)) continue;

      return text;
    }
    return null;
  }
}
