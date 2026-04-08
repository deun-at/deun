import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/receipt_scan_result.dart';

/// A single OCR line with text and spatial info from ML Kit bounding boxes.
class ReceiptLine {
  final String text;
  final double top;
  final double left;
  final double right;
  final double height;

  const ReceiptLine({
    required this.text,
    required this.top,
    required this.left,
    required this.right,
    required this.height,
  });

  /// For tests: create a line with only text + top position.
  @visibleForTesting
  factory ReceiptLine.simple(String text, double top) => ReceiptLine(
        text: text,
        top: top,
        left: 0,
        right: 200,
        height: 12,
      );
}

class ReceiptParser {
  // --- Exclusion keywords (lines containing any of these are skipped) ---
  static final _exclusionKeywords = [
    // Tax / VAT
    'mwst', 'ust', 'tax', 'steuer', 'netto',
    // Discounts / promotions
    'rabatt', 'discount', 'aktion',
    // Payment methods
    'visa', 'mastercard', 'master card', 'bankomat', 'kontaktlos',
    'kreditkarte', 'bezahlt', 'bezahlung', 'contless', 'contactless',
    'gegeben', 'wechselgeld', 'rückgeld',
    'bezahlweise', 'zahlungsart',
    // Sub-totals (not the main total)
    'zwischensumme', 'subtotal',
    // Receipt metadata
    'kassa', 'bon-nr', 'filiale', 'beleg', 'terminal', 'trace',
    'rechnungs', 'belegnr', 'kassier', 'bedient',
    'datum:', 'zeit:', 'uhrzeit', 'uhrzeit:',
    'vr-nr', 'trace-nr', 'cap-perf', 'as-proc', 'as-zeit',
    'kundenbeleg', 'verkauf', 'privat',
    'globalbonus', 'kartentyp', 'kartennr',
    // VAT / company IDs
    'atu', 'uid', 'steuernummer', 'firmenbuch',
    // Store info patterns
    'tel ', 'tel.', 'fax', 'office@',
    // Misc receipt noise
    'pfand', 'leergut',
    'danke', 'vielen dank', 'wiedersehen',
    'ihren einkauf', 'einkauf und',
    'kassabon', 'rechnung',
    'umtausch', 'garantie', 'originalverpack',
    // Card transaction details
    'pan seq', 'aid:', 'mid:', 'tid:',
    'kin/', 'efs:', 'efi:',
  ];

  static final _totalKeywords = [
    'total', 'sum', 'summe', 'gesamt', 'gesamtbetrag',
    'zu zahlen', 'betrag', 'endbetrag', 'amount due',
    'grand total', 'brutto',
  ];

  // Matches amounts like: 12.50, 12,50, 1.234,56, 1,234.56, €12.50
  static final _amountRegex = RegExp(
    r'[\€\$]?\s*(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[\€\$]?',
  );

  // Matches negative amounts: -1.00, -0.39
  static final _negativeAmountRegex = RegExp(
    r'-\s*\d{1,3}(?:[.,]\d{3})*[.,]\d{2}',
  );

  // Matches quantity patterns: "3x", "3 x", "3X", leading or trailing
  static final _quantityPrefixRegex = RegExp(r'^(\d+)\s*[xX]\s+');
  static final _quantitySuffixRegex = RegExp(r'\s+[xX]\s*(\d+)$');

  static final _datePatterns = [
    RegExp(r'(\d{2})\.(\d{2})\.(\d{4})'), // DD.MM.YYYY
    RegExp(r'(\d{2})\.(\d{2})\.(\d{2})\b'), // DD.MM.YY
    RegExp(r'(\d{4})-(\d{2})-(\d{2})'), // YYYY-MM-DD
    RegExp(r'(\d{2})/(\d{2})/(\d{4})'), // DD/MM/YYYY
  ];

  // Lines matching these are metadata noise, not items
  static final _metadataPatterns = [
    RegExp(r'www\.', caseSensitive: false),
    RegExp(r'https?://', caseSensitive: false),
    RegExp(r'@'), // emails
    RegExp(r'[a-zA-Z]\.[a-zA-Z]{2,3}$'), // domain endings (.at, .com, .de)
    RegExp(r'^\d{5,}$'), // barcode / long numbers
    RegExp(r'^\d[\d\s\-\+\/\.]{6,}$'), // phone/fax numbers
    RegExp(r'^\*+'), // separator lines (****)
    RegExp(r'^-{3,}'), // separator lines (----)
    RegExp(r'^={3,}'), // separator lines (====)
    RegExp(r'^\#{3,}'), // separator lines (####)
    // Store slogans / branding that aren't the store name
    RegExp(r'^voller leben$', caseSensitive: false),
  ];

  /// Words that indicate a line is a promo/category label, not an item.
  /// These lines have no amount but appear between items.
  static final _promoLabelPatterns = [
    RegExp(r'^extrem\b', caseSensitive: false),
    RegExp(r'^mein rabatt', caseSensitive: false),
    RegExp(r'^ihr rabatt', caseSensitive: false),
    RegExp(r'^spar\s', caseSensitive: false),
    RegExp(r'^aktion\b', caseSensitive: false),
    RegExp(r'^angebot\b', caseSensitive: false),
    RegExp(r'^aktions', caseSensitive: false),
  ];

  /// Single-letter tax category codes used by Austrian supermarkets (BILLA, etc.)
  /// after the price. Strip these from item names.
  static final _taxCategorySuffix = RegExp(r'\s+[A-Z]{1,2}$');

  static ReceiptScanResult parse(List<TextBlock> blocks) {
    final lines = _extractSortedLines(blocks);

    final date = extractDate(lines);
    final total = extractTotal(lines);
    final totalLineIndex = _findTotalLineIndex(lines);
    final lineItems = _extractLineItems(lines, total, totalLineIndex);
    final merchantName = extractMerchantName(lines);

    return ReceiptScanResult(
      merchantName: merchantName,
      date: date,
      lineItems: lineItems,
      total: total,
    );
  }

  static List<ReceiptLine> _extractSortedLines(List<TextBlock> blocks) {
    final lines = <ReceiptLine>[];
    for (final block in blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        lines.add(ReceiptLine(
          text: line.text.trim(),
          top: box.top,
          left: box.left,
          right: box.right,
          height: box.height,
        ));
      }
    }
    lines.sort((a, b) => a.top.compareTo(b.top));
    return lines;
  }

  @visibleForTesting
  static DateTime? extractDate(List<ReceiptLine> lines) {
    final now = DateTime.now();

    for (final line in lines) {
      for (int i = 0; i < _datePatterns.length; i++) {
        final match = _datePatterns[i].firstMatch(line.text);
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

  @visibleForTesting
  static double? parseAmount(String amountStr) {
    final cleaned = amountStr.replaceAll(RegExp(r'[\€\$\s]'), '');
    final lastComma = cleaned.lastIndexOf(',');
    final lastPeriod = cleaned.lastIndexOf('.');

    String normalized;
    if (lastComma > lastPeriod) {
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastPeriod > lastComma) {
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
    return parseAmount(matches.last.group(1)!);
  }

  /// Check if a line contains a negative amount (discount line).
  @visibleForTesting
  static bool hasNegativeAmount(String text) {
    return _negativeAmountRegex.hasMatch(text);
  }

  /// Check if a line is "amount-only" (just a number, no meaningful text).
  @visibleForTesting
  static bool isAmountOnly(String text) {
    final stripped = text
        .replaceAll(_amountRegex, '')
        .replaceAll(RegExp(r'[\s\€\$\dx]'), '')
        .trim();
    return stripped.isEmpty || stripped.length <= 2;
  }

  /// Check if a line is a promo/category label (e.g., "EXTREM AKTION").
  @visibleForTesting
  static bool isPromoLabel(String text) {
    return _promoLabelPatterns.any((p) => p.hasMatch(text));
  }

  /// Check if a line should be skipped entirely.
  @visibleForTesting
  static bool isSkippable(String text) {
    final lower = text.toLowerCase();
    if (_exclusionKeywords.any((kw) => lower.contains(kw))) return true;
    if (_totalKeywords.any((kw) => lower.contains(kw))) return true;
    if (_datePatterns.any((p) => p.hasMatch(text))) return true;
    if (_metadataPatterns.any((p) => p.hasMatch(text))) return true;
    if (hasNegativeAmount(text)) return true;
    if (isPromoLabel(text)) return true;
    return false;
  }

  /// Find the index of the total line (used for section detection).
  static int? _findTotalLineIndex(List<ReceiptLine> lines) {
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].text.toLowerCase();
      if (_totalKeywords.any((kw) => lower.contains(kw))) {
        return i;
      }
    }
    return null;
  }

  /// Estimate where the "header" ends based on the first item-like line.
  /// Returns the index of the first plausible item line.
  @visibleForTesting
  static int estimateHeaderEnd(List<ReceiptLine> lines) {
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text;
      if (isSkippable(text)) continue;

      final amount = _lineAmount(text);
      if (amount != null && amount > 0 && !isAmountOnly(text)) {
        return i;
      }
    }
    return 0;
  }

  @visibleForTesting
  static double? extractTotal(List<ReceiptLine> lines) {
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].text.toLowerCase();
      if (!_totalKeywords.any((kw) => lower.contains(kw))) continue;

      final amount = _lineAmount(lines[i].text);
      if (amount != null && amount > 0) return amount;

      for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
        final nextAmount = _lineAmount(lines[j].text);
        if (nextAmount != null && nextAmount > 0) return nextAmount;
      }
    }

    // Fallback: largest amount on the receipt
    double maxAmount = 0;
    for (final line in lines) {
      final amount = _lineAmount(line.text);
      if (amount != null && amount > maxAmount) maxAmount = amount;
    }
    return maxAmount > 0 ? maxAmount : null;
  }

  @visibleForTesting
  static (String, int) extractQuantity(String name) {
    final prefixMatch = _quantityPrefixRegex.firstMatch(name);
    if (prefixMatch != null) {
      int qty = int.tryParse(prefixMatch.group(1)!) ?? 1;
      String cleanName = name.substring(prefixMatch.end).trim();
      if (qty > 0 && cleanName.length >= 2) return (cleanName, qty);
    }

    final suffixMatch = _quantitySuffixRegex.firstMatch(name);
    if (suffixMatch != null) {
      int qty = int.tryParse(suffixMatch.group(1)!) ?? 1;
      String cleanName = name.substring(0, suffixMatch.start).trim();
      if (qty > 0 && cleanName.length >= 2) return (cleanName, qty);
    }

    return (name, 1);
  }

  /// Clean up an item name:
  /// - Strip trailing tax category codes (B, CI, A etc.) used by Austrian stores
  /// - Strip trailing punctuation/whitespace
  @visibleForTesting
  static String cleanItemName(String name) {
    // Strip trailing single/double letter tax codes (e.g., "Vollmilch B" → "Vollmilch")
    var cleaned = name.replaceAll(_taxCategorySuffix, '').trim();
    // Strip trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[\s\.\,\-\*]+$'), '').trim();
    return cleaned;
  }

  /// Extract line items, restricted to the item zone
  /// (after header, before/at total line).
  static List<ReceiptLineItem> _extractLineItems(
      List<ReceiptLine> lines, double? total, int? totalLineIndex) {
    final items = <ReceiptLineItem>[];
    final headerEnd = estimateHeaderEnd(lines);
    final itemsEnd = totalLineIndex ?? lines.length;

    for (int i = headerEnd; i < itemsEnd; i++) {
      final text = lines[i].text;
      if (isSkippable(text)) continue;

      final amount = _lineAmount(text);

      if (amount != null && amount > 0) {
        // Pattern 1: amount is on this line
        if (!isAmountOnly(text)) {
          final amountMatch = _amountRegex.firstMatch(text);
          String name = text;
          if (amountMatch != null) {
            name = text.substring(0, amountMatch.start).trim();
          }
          name = cleanItemName(name);

          if (name.length >= 3 && amount != total && _isPlausiblePrice(amount)) {
            final (cleanName, qty) = extractQuantity(name);
            items.add(ReceiptLineItem(
              name: cleanName,
              amount: amount,
              quantity: qty,
            ));
          }
        }
      } else {
        // Pattern 2: this line has no amount — look ahead for the price
        if (text.length < 3) continue;
        if (RegExp(r'^\d[\d\s\-\+\/\.]*$').hasMatch(text)) continue;

        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextText = lines[j].text;
          final nextAmount = _lineAmount(nextText);
          if (nextAmount != null &&
              nextAmount > 0 &&
              isAmountOnly(nextText)) {
            if (nextAmount != total && _isPlausiblePrice(nextAmount)) {
              final cleanName = cleanItemName(text);
              if (cleanName.length < 3) break;
              final (finalName, qty) = extractQuantity(cleanName);
              items.add(ReceiptLineItem(
                name: finalName,
                amount: nextAmount,
                quantity: qty,
              ));
            }
            break;
          }
          if (!isAmountOnly(nextText) && nextText.length >= 3) break;
        }
      }
    }
    return items;
  }

  /// Reject implausibly small or large prices for typical grocery items.
  static bool _isPlausiblePrice(double amount) {
    return amount >= 0.05 && amount <= 9999.0;
  }

  @visibleForTesting
  static String? extractMerchantName(List<ReceiptLine> lines) {
    // Look at top lines only (max first 8 lines — header area)
    final searchLimit = lines.length < 8 ? lines.length : 8;
    double maxHeight = 0;
    String? tallestLine;

    for (int i = 0; i < searchLimit; i++) {
      final text = lines[i].text;
      if (text.isEmpty || text.length < 3) continue;
      if (_amountRegex.hasMatch(text)) continue;
      if (_datePatterns.any((p) => p.hasMatch(text))) continue;

      final lower = text.toLowerCase();
      if (_totalKeywords.any((kw) => lower.contains(kw))) continue;
      if (_exclusionKeywords.any((kw) => lower.contains(kw))) continue;
      if (_metadataPatterns.any((p) => p.hasMatch(text))) continue;

      if (RegExp(r'^\d[\d\s\-\+\/\.]*$').hasMatch(text)) continue;
      // Skip address-like lines (number + street name pattern)
      if (RegExp(r'^\d+\s+\w').hasMatch(text) && text.length < 40) continue;
      // Skip postal code lines (e.g., "1010 Wien")
      if (RegExp(r'^\d{4,5}\s+\w').hasMatch(text)) continue;
      // Skip company type suffixes on their own line (AG, GmbH, e.U.)
      if (RegExp(r'^(AG|GmbH|e\.U\.|KG|OG)$', caseSensitive: false).hasMatch(text)) continue;

      // Prefer the tallest text in the header (usually the store name)
      if (lines[i].height > maxHeight) {
        maxHeight = lines[i].height;
        tallestLine = text;
      }
    }

    return tallestLine;
  }
}
