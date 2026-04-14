import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/receipt_scan_result.dart';

class GeminiReceiptParser {
  static bool get isAvailable => Supabase.instance.client.auth.currentUser != null;

  /// Parse receipt OCR text lines via the Supabase Edge Function.
  /// Returns null if parsing fails (not authenticated, network error, bad response).
  static Future<ReceiptScanResult?> parse(List<String> ocrLines) async {
    if (!isAvailable) return null;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'parse-receipt',
        body: {'ocrLines': ocrLines},
      );

      if (response.status != 200) {
        debugPrint('Receipt parser error: ${response.status}');
        return null;
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return _parseResponse(data as String);
      }
      return _parseJson(data);
    } catch (e) {
      debugPrint('GeminiReceiptParser error: $e');
      return null;
    }
  }

  static ReceiptScanResult? _parseResponse(String responseText) {
    try {
      final json = jsonDecode(responseText) as Map<String, dynamic>;
      return _parseJson(json);
    } catch (e) {
      debugPrint('GeminiReceiptParser JSON parse error: $e');
      return null;
    }
  }

  static ReceiptScanResult? _parseJson(Map<String, dynamic> json) {
    try {
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
