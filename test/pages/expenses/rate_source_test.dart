import 'dart:io';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// A EUR-based rate table covering every code in `kSupportedCurrencies` bar EUR
/// itself, in the shape and rough magnitudes the provider publishes.
///
/// **Hand-authored, not captured from the provider.** That bounds what the sweep
/// below can prove: that `RateSource` resolves every pickable currency without
/// special-casing any of them, and that the app's list and this table cannot
/// drift apart. It does **not** prove the provider actually quotes ISK, TRY or
/// IDR — only a request to the live function shows that, which is step 8 of this
/// feature's entry in `docs/ristretto/manual-checks.md`.
///
/// A code the provider does not quote is not a correctness hazard: it resolves
/// to null and degrades to the visible manual-entry fallback, never to a
/// substituted rate.
const _syntheticEcbRates = <String, double>{
  'USD': 1.0842,
  'JPY': 161.23,
  'BGN': 1.9558,
  'CZK': 25.312,
  'DKK': 7.4589,
  'GBP': 0.85338,
  'HUF': 394.28,
  'PLN': 4.2915,
  'RON': 4.9758,
  'SEK': 11.2185,
  'CHF': 0.9602,
  'ISK': 149.30,
  'NOK': 11.5940,
  'TRY': 35.482,
  'AUD': 1.6404,
  'BRL': 5.9137,
  'CAD': 1.4823,
  'CNY': 7.8365,
  'HKD': 8.4677,
  'IDR': 17264.19,
  'ILS': 4.0318,
  'INR': 90.556,
  'KRW': 1478.62,
  'MXN': 19.827,
  'MYR': 4.8219,
  'NZD': 1.7896,
  'PHP': 61.284,
  'SGD': 1.4512,
  'THB': 37.418,
  'ZAR': 19.7104,
};

const _recordedDate = '2026-09-10';

/// A transport that answers exactly as the Edge Function's wire contract says,
/// off the table above, and records what it was asked.
class _RecordedTransport {
  final List<Map<String, dynamic>> calls = [];

  Future<Map<String, dynamic>?> call(Map<String, dynamic> body) async {
    calls.add(body);
    final base = body['base'] as String;
    final quote = body['quote'] as String;
    if (base == quote) {
      return {'rate': 1.0, 'date': body['date'], 'base': base, 'quote': quote};
    }
    // The table is EUR-based; a EUR quote is 1 / the base's EUR rate.
    final baseRate = base == 'EUR' ? 1.0 : _syntheticEcbRates[base];
    final quoteRate = quote == 'EUR' ? 1.0 : _syntheticEcbRates[quote];
    if (baseRate == null || quoteRate == null) return {'error': 'no_rate'};
    return {
      'rate': quoteRate / baseRate,
      'date': _recordedDate,
      'base': base,
      'quote': quote,
    };
  }
}

void main() {
  // AC: the prefill is for the expense's date, and the form states which date
  // the rate is attributed to — so the EFFECTIVE date has to survive the read.
  test(
    'a quote carries the rate and the EFFECTIVE date, not the requested one',
    () async {
      final source = RateSource(
        transport: (_) async => {'rate': 0.9432, 'date': '2026-06-30'},
      );
      final quote = await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        // A Sunday. Reference rates publish on business days.
        date: DateTime(2026, 7, 5),
      );
      expect(quote, isNotNull);
      expect(quote!.rate, 0.9432);
      expect(quote.effectiveDate, DateTime(2026, 6, 30));
    },
  );

  test(
    'the request names the pair and the date in the function wire shape',
    () async {
      final calls = <Map<String, dynamic>>[];
      final source = RateSource(
        transport: (body) async {
          calls.add(body);
          return {'rate': 0.9432, 'date': '2026-07-01'};
        },
      );
      await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2026, 7, 1),
      );
      expect(calls.single, {
        'base': 'CHF',
        'quote': 'EUR',
        'date': '2026-07-01',
      });
    },
  );

  // AC: repeated requests for the same pair and date are served from cache.
  test(
    'the same pair and date is served from cache — one call, not two',
    () async {
      final transport = _RecordedTransport();
      final source = RateSource(transport: transport.call);
      final first = await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2026, 7, 1),
      );
      final second = await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2026, 7, 1),
      );
      expect(transport.calls, hasLength(1));
      expect(second, first);
    },
  );

  test('the cache key includes the DATE — another day is a miss', () async {
    final transport = _RecordedTransport();
    final source = RateSource(transport: transport.call);
    await source.fetchRate(
      base: Currency.chf,
      quote: Currency.eur,
      date: DateTime(2026, 7, 1),
    );
    await source.fetchRate(
      base: Currency.chf,
      quote: Currency.eur,
      date: DateTime(2026, 7, 2),
    );
    await source.fetchRate(
      base: Currency.jpy,
      quote: Currency.eur,
      date: DateTime(2026, 7, 1),
    );
    expect(transport.calls, hasLength(3));
  });

  // AC: unreachable service => manual entry. Never 1:1, never a throw.
  test(
    'an unreachable service yields null, never a 1:1 rate, and is retried',
    () async {
      var attempts = 0;
      final source = RateSource(
        transport: (_) async {
          attempts++;
          throw const SocketException('offline');
        },
      );
      final quote = await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2026, 7, 1),
      );
      expect(quote, isNull, reason: 'a failure is not a rate of 1.0');
      // A failure is NOT cached: a transient outage must not shadow the whole
      // session.
      await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2026, 7, 1),
      );
      expect(attempts, 2);
    },
  );

  test('a no_rate answer for the date yields null', () async {
    // What the function returns for a weekend with no walk-back, a date before
    // coverage, or a future date.
    final source = RateSource(transport: (_) async => {'error': 'no_rate'});
    expect(
      await source.fetchRate(
        base: Currency.chf,
        quote: Currency.eur,
        date: DateTime(2030, 1, 1),
      ),
      isNull,
    );
  });

  test('a malformed body yields null rather than throwing', () async {
    for (final body in <Map<String, dynamic>?>[
      null,
      {'rate': 0.9432}, // no date
      {'date': '2026-07-01'}, // no rate
      {'rate': 0, 'date': '2026-07-01'}, // not a usable rate
      {'rate': -1, 'date': '2026-07-01'},
      {'rate': 'nonsense', 'date': '2026-07-01'},
      {'rate': 0.9432, 'date': 42},
    ]) {
      final source = RateSource(transport: (_) async => body);
      expect(
        await source.fetchRate(
          base: Currency.chf,
          quote: Currency.eur,
          date: DateTime(2026, 7, 1),
        ),
        isNull,
        reason: 'body $body must degrade to manual entry',
      );
    }
  });

  // AC: every code in kSupportedCurrencies returns a rate for a recent weekday.
  // This proves the CLIENT half — no code is special-cased, and the app's list
  // cannot drift from the fixture. That the provider quotes each one is step 8
  // of the manual check; see the fixture's docstring.
  test(
    'every supported currency resolves, and the app list matches the fixture',
    () async {
      final transport = _RecordedTransport();
      final source = RateSource(transport: transport.call);
      for (final currency in kSupportedCurrencies) {
        final quote = await source.fetchRate(
          base: currency,
          quote: Currency.eur,
          date: DateTime.parse(_recordedDate),
        );
        expect(quote, isNotNull, reason: '${currency.code} has no rate');
        expect(quote!.rate, greaterThan(0));
      }
      // ...and the fixture is the app's own list, not a subset that happens to
      // pass: a currency added to kSupportedCurrencies without a quote fails here.
      expect(kSupportedCurrencies.map((c) => c.code).toSet(), {
        'EUR',
        ..._syntheticEcbRates.keys,
      });
    },
  );

  // AC [human, in part]: rates are fetched through an Edge Function rather than
  // directly from the client. The deployed half is the manual check; that the
  // CLIENT has no other way out is provable here and now.
  test('the only transport is the exchange-rate Edge Function', () {
    final source = File(
      'lib/pages/expenses/service/rate_source.dart',
    ).readAsStringSync();
    expect(
      RegExp(r"functions\.invoke\(\s*'exchange-rate'").hasMatch(source),
      isTrue,
      reason: 'the function call is the only way out of the client',
    );
    // `package:http` is not re-asserted here — multi_currency_group_test.dart
    // already sweeps all of lib/ for it. These two are not covered by that
    // sweep, and they are the ways a direct fetch could creep back in without
    // a new dependency.
    expect(source, isNot(contains('HttpClient')));
    expect(source, isNot(contains('Uri.parse')));
  });
}
