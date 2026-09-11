import 'dart:io';

import 'package:deun/helper/helper.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = 'supabase/functions/exchange-rate/index.ts';

/// Source-shape assertions for server code this build cannot execute — the same
/// idiom `expense_rate_migration_test.dart` uses for the migration. The live
/// behaviour is the manual check.
///
/// These assert the *refusals the Contract forbids skipping*, not the function's
/// prose: a reformat of `index.ts` should not redden them, but deleting a guard
/// must.
void main() {
  group('the exchange-rate Edge Function', () {
    late String source;

    setUpAll(() {
      source = File(_path).readAsStringSync();
    });

    test('exists and answers the CORS preflight', () {
      // The reason the fetch is server-side at all: the web build must not be
      // exposed to the provider's CORS behaviour.
      expect(File(_path).existsSync(), isTrue);
      expect(source, contains('Access-Control-Allow-Origin'));
      expect(source, contains("req.method === 'OPTIONS'"));
    });

    test('refuses a future date instead of returning the latest rate', () {
      // One day of slack is deliberate — the client sends the device's LOCAL
      // date and this function's clock is UTC, so a user east of UTC is a day
      // ahead for part of their morning. Anything beyond that is genuinely in
      // the future and gets no rate.
      expect(
        RegExp(
          r'daysBetween\(\s*today\(\)\s*,\s*date\s*\)\s*>\s*1',
        ).hasMatch(source),
        isTrue,
        reason: 'a future date must be refused, with one day of timezone slack',
      );
      expect(source, contains("error: 'no_rate'"));
    });

    test('returns the provider EFFECTIVE date, never an echo of the request', () {
      // `date:` in the success payload must be the provider's own date, not the
      // requested one — a Saturday expense carries Friday's rate, and saying
      // otherwise would attribute a rate to a day it was never quoted on.
      expect(
        RegExp(r'const effective\s*=.*data\??\.date').hasMatch(source),
        isTrue,
        reason: 'the effective date has to come off the provider response',
      );
      expect(
        RegExp(r'json\(\s*\{\s*rate,\s*date:\s*effective').hasMatch(source),
        isTrue,
        reason: 'the success payload must carry the effective date',
      );
      // ...and refuses an effective date too far from the requested one, which
      // is how the provider answers a date before its coverage begins.
      expect(
        RegExp(
          r'daysBetween\(\s*effective\s*,\s*date\s*\)\s*>\s*7',
        ).hasMatch(source),
        isTrue,
        reason: 'a walk-back beyond a week is a rate for the wrong day',
      );
    });

    test('caches by pair AND date', () {
      expect(
        RegExp(r'cache\.get\(|cache\.set\(').hasMatch(source),
        isTrue,
        reason: 'repeat requests for a pair and date must not refetch',
      );
      expect(
        RegExp(r'const key\s*=.*base.*quote.*date').hasMatch(source),
        isTrue,
        reason: 'the cache key has to include the date, not just the pair',
      );
      // A historical rate cannot change; today's still can.
      expect(source, contains('YEAR_MS'));
      expect(source, contains('HOUR_MS'));
    });

    test('accepts exactly the currencies the app can pick', () {
      for (final currency in kSupportedCurrencies) {
        expect(
          source,
          contains("'${currency.code}'"),
          reason: '${currency.code} is pickable in the app but not upstream',
        );
      }
      expect(source, contains("error: 'unsupported_currency'"));
    });
  });
}
