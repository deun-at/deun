import 'dart:convert';

import 'package:async_preferences/async_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'currency_conversion.dart';
import 'helper.dart';

/// Persisted-preferences key for the last-known exchange rates cache.
const String kExchangeRatesCachePrefKey = 'exchange_rates_cache';

/// Free, no-key exchange-rate endpoint (frankfurter.app, ECB reference rates).
/// Base is fixed to [kDefaultCurrencyCode] (EUR) so the cache stays consistent
/// regardless of the user's home currency; [ExchangeRates.conversionRate]
/// converts between any two currencies from a single base table.
const String _kRatesUrl =
    'https://api.frankfurter.app/latest?base=$kDefaultCurrencyCode';

/// Fetches and caches current cross-group conversion rates. Display-only: the
/// rates are used to convert aggregates into the home currency and never touch
/// the ledger.
class ExchangeRateService {
  ExchangeRateService({AsyncPreferences? preferences, http.Client? client})
    : _preferences = preferences ?? AsyncPreferences(),
      _client = client ?? http.Client();

  final AsyncPreferences _preferences;
  final http.Client _client;

  /// Loads current rates: fetches live rates and refreshes the last-known cache
  /// on success; on any failure (offline) falls back to the cached rates; with
  /// no cache at all returns `null` so callers exclude foreign contributions.
  Future<ExchangeRates?> loadRates() async {
    try {
      final response = await _client
          .get(Uri.parse(_kRatesUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = ExchangeRates.fromApiJson(json);
        await _preferences.setString(
          kExchangeRatesCachePrefKey,
          jsonEncode(rates.toCacheJson()),
        );
        return rates;
      }
    } catch (e) {
      debugPrint('Exchange-rate fetch failed, using last known rates: $e');
    }
    return _cachedRates();
  }

  Future<ExchangeRates?> _cachedRates() async {
    try {
      final cached = await _preferences.getString(kExchangeRatesCachePrefKey);
      if (cached == null || cached.isEmpty) return null;
      return ExchangeRates.fromApiJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Exchange-rate cache read failed: $e');
      return null;
    }
  }
}
