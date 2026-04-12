import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../data/receipt_scan_result.dart';

class GeminiReceiptParser {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get isAvailable => _apiKey.isNotEmpty;

  static const _prompt = '''
Extract receipt data from this OCR text. Return ONLY valid JSON, no markdown fences or extra text.

Expected format:
{"merchant": "store name or null", "date": "YYYY-MM-DD or null", "items": [{"name": "item name", "amount": 1.99, "quantity": 1}], "total": 12.50}

Rules:
- All amounts as decimal numbers (1.99 not "1,99")
- Date as ISO YYYY-MM-DD
- Skip tax lines, VAT, payment method lines, subtotals
- Include discounts (e.g. "Rabatt") as items with negative amounts (e.g. -0.50)
- quantity defaults to 1, only set higher if explicitly stated (e.g. "3x")
- If unsure about a field, use null
- For items, extract the product name and its price
- The total should be the final amount paid

OCR text:
''';

  /// Parse receipt OCR text lines using Gemini Flash.
  /// Returns null if parsing fails (no API key, network error, bad response).
  static Future<ReceiptScanResult?> parse(List<String> ocrLines) async {
    if (!isAvailable) return null;

    try {
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        ),
      );

      final prompt = _prompt + ocrLines.join('\n');
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) return null;

      return _parseResponse(text);
    } catch (e) {
      debugPrint('GeminiReceiptParser error: $e');
      return null;
    }
  }

  static ReceiptScanResult? _parseResponse(String responseText) {
    try {
      // Strip markdown fences if present despite our instruction
      var cleaned = responseText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final merchant = json['merchant'] as String?;

      DateTime? date;
      if (json['date'] != null) {
        date = DateTime.tryParse(json['date'] as String);
      }

      double? total;
      if (json['total'] != null) {
        total = (json['total'] as num?)?.toDouble();
      }

      final items = <ReceiptLineItem>[];
      if (json['items'] is List) {
        for (final item in json['items'] as List) {
          if (item is Map<String, dynamic>) {
            final name = item['name'] as String?;
            final amount = (item['amount'] as num?)?.toDouble();
            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            if (name != null && name.isNotEmpty && amount != null && amount != 0) {
              items.add(ReceiptLineItem(
                name: name,
                amount: amount,
                quantity: quantity,
              ));
            }
          }
        }
      }

      return ReceiptScanResult(
        merchantName: merchant,
        date: date,
        lineItems: items,
        total: total,
      );
    } catch (e) {
      debugPrint('GeminiReceiptParser JSON parse error: $e');
      return null;
    }
  }
}
