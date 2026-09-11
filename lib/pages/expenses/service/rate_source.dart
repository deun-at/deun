import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/helper.dart';

/// One rate, as the rate source actually quoted it.
@immutable
class RateQuote {
  const RateQuote({required this.rate, required this.effectiveDate});

  /// 1 base currency = [rate] quote currency.
  final double rate;

  /// The day the rate is ACTUALLY attributed to, which is often not the day it
  /// was asked for: reference rates publish on business days, so a Saturday
  /// expense resolves to Friday's rate. This is the date the editor shows and
  /// the date frozen on the row — echoing the request instead would attribute a
  /// rate to a day it was never quoted on.
  final DateTime effectiveDate;

  @override
  bool operator ==(Object other) =>
      other is RateQuote &&
      other.rate == rate &&
      other.effectiveDate == effectiveDate;

  @override
  int get hashCode => Object.hash(rate, effectiveDate);

  @override
  String toString() => 'RateQuote(${formatRate(rate)} @ ${ymd(effectiveDate)})';
}

/// The transport, as an injectable function: takes the request body, returns the
/// decoded JSON response, or null when there is none.
///
/// Production is [RateSource._invokeFunction]. A test supplies its own so the
/// failure and offline paths — the ones that matter most, and the only ones a
/// user ever meets when the service is down — are reachable without a deployed
/// function.
typedef RateTransport =
    Future<Map<String, dynamic>?> Function(Map<String, dynamic> body);

/// The lookup as the expense editor consumes it. [fetchRate] satisfies it, and
/// so does a test's stub.
typedef RateLookup =
    Future<RateQuote?> Function({
      required Currency base,
      required Currency quote,
      required DateTime date,
    });

/// Reads historical reference rates through the `exchange-rate` Edge Function.
///
/// Everything about this class is "a prefill is a convenience": every failure —
/// offline, a non-2xx, a body that is not the shape the function promises —
/// resolves to null so the editor falls back to manual entry. It NEVER
/// substitutes 1:1 and never substitutes another day's rate for the one asked
/// for; the function refuses those upstream and a null is what arrives here.
class RateSource {
  RateSource({RateTransport? transport})
    : _transport = transport ?? _invokeFunction;

  final RateTransport _transport;

  /// In-session cache, keyed by pair AND date. Successful quotes only: caching
  /// a failure would freeze a transient outage for the life of the session,
  /// while a rate for a given pair and day is immutable.
  final Map<String, RateQuote> _cache = {};

  Future<RateQuote?> fetchRate({
    required Currency base,
    required Currency quote,
    required DateTime date,
  }) async {
    final key = '${base.code}|${quote.code}|${ymd(date)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = await _read(base: base, quote: quote, date: date);
    if (result != null) _cache[key] = result;
    return result;
  }

  Future<RateQuote?> _read({
    required Currency base,
    required Currency quote,
    required DateTime date,
  }) async {
    try {
      final json = await _transport({
        'base': base.code,
        'quote': quote.code,
        'date': ymd(date),
      });
      if (json == null) return null;

      final rate = (json['rate'] as num?)?.toDouble();
      final rawDate = json['date'];
      final effective = rawDate is String ? DateTime.tryParse(rawDate) : null;
      if (rate == null || !rate.isFinite || rate <= 0 || effective == null) {
        return null;
      }
      return RateQuote(rate: rate, effectiveDate: effective);
    } catch (e) {
      debugPrint('rate prefill unavailable: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _invokeFunction(
    Map<String, dynamic> body,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      'exchange-rate',
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return null;
  }
}

/// The app's rate source. One instance so the in-session cache is shared across
/// every editor the user opens rather than refetching per screen.
final RateSource rateSource = RateSource();

/// The rate for [date], or null when there is none to be had.
Future<RateQuote?> fetchRate({
  required Currency base,
  required Currency quote,
  required DateTime date,
}) => rateSource.fetchRate(base: base, quote: quote, date: date);
