import 'dart:async';
import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The editor harness, shared with the suite that owns the manual rate field
// rather than copied. `show` keeps that file's own `main` out of this one.
import 'expense_editor_currency_rate_test.dart'
    show
        convertedExpense,
        initTestSupabase,
        installFakePrefs,
        pickCurrency,
        prefsValues,
        pumpEditor,
        pumpEditorWithSaveSeam,
        saveEditor;

/// A rate lookup that answers off a table keyed by `yyyy-MM-dd` and records
/// every call, so "was it refetched, and for which date" is directly assertable.
class _StubLookup {
  _StubLookup(this.byDate, {this.gate});

  final Map<String, RateQuote> byDate;

  /// When set, responses wait on it — how "a late answer never wins" is staged.
  final Completer<void>? gate;

  final List<DateTime> calls = [];

  Future<RateQuote?> call({
    required Currency base,
    required Currency quote,
    required DateTime date,
  }) async {
    calls.add(date);
    if (gate != null) await gate!.future;
    return byDate[ymd(date)];
  }
}

String _rateText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('expense_rate_field')))
    .controller!
    .text;

/// Yesterday, date-only — what `DateOption.yesterday` resolves to.
final DateTime _yesterday = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
).subtract(const Duration(days: 1));

/// Changes the expense's date through the real date row, so the
/// `FormBuilderField`'s `onChanged` is what fires — not a direct `didChange`,
/// which would prove nothing about the wiring.
///
/// "Yesterday" rather than a calendar date on purpose: `DateOption.pick` defers
/// to the platform `showDatePicker`, and the quick option reaches the same
/// `field.didChange` with none of that. Driver copied from
/// `expense_detail_tiles_test.dart`, including the drag — the date row sits
/// below the fold at the default test viewport.
Future<void> _pickYesterday(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.dragUntilVisible(
    find.text(l10n.expenseWhen),
    find.byType(Scrollable).first,
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.expenseWhen));
  await tester.pumpAndSettle();
  // "Today" is also the tile's own value text, so scope to the sheet.
  await tester.tap(
    find.descendant(
      of: find.byType(DateOptionsSheet),
      matching: find.text(l10n.dateYesterday),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestSupabase);

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(installFakePrefs);

  // AC: the prefill is for the EXPENSE's date, not today's.
  testWidgets(
    'choosing a foreign currency prefills the rate for the expense date',
    (tester) async {
      final lookup = _StubLookup({
        '2026-07-01': RateQuote(
          rate: 0.9432,
          effectiveDate: DateTime(2026, 6, 30),
        ),
      });
      // The harness expense is dated 2026-07-01.
      await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();

      expect(lookup.calls.single, DateTime(2026, 7, 1));
      expect(_rateText(tester), '0.9432');
    },
  );

  // AC: the form states which date the rate is attributed to.
  testWidgets('the form names the date the prefilled rate is attributed to', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final lookup = _StubLookup({
      // A Wednesday expense; the rate quoted the previous Tuesday.
      '2026-07-01': RateQuote(
        rate: 0.9432,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    });
    await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('expense_rate_prefill_date')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.expenseRatePrefilledOn(formatDate('2026-06-30'))),
      findsOneWidget,
    );
  });

  // AC: the prefill is editable and a user-entered rate is what gets frozen.
  testWidgets(
    'a rate typed over the prefill is what gets frozen, with its own date',
    (tester) async {
      final lookup = _StubLookup({
        '2026-07-01': RateQuote(
          rate: 0.9432,
          effectiveDate: DateTime(2026, 6, 30),
        ),
      });
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        lookupRate: lookup.call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '0.91',
      );
      await tester.pumpAndSettle();
      await saveEditor(tester);

      expect(saved.single.conversion!.rate, 0.91);
      // The effective date belonged to the suggestion, not to the typed number.
      expect(saved.single.conversion!.rateDate, ymd(DateTime.now()));
      expect(
        find.byKey(const ValueKey('expense_rate_prefill_date')),
        findsNothing,
      );
    },
  );

  // AC: nothing in this feature can overwrite a rate the user typed.
  testWidgets('a rate arriving LATE never overwrites one the user has typed', (
    tester,
  ) async {
    final gate = Completer<void>();
    final lookup = _StubLookup({
      '2026-07-01': RateQuote(
        rate: 0.9432,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    }, gate: gate);
    await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
    await pickCurrency(tester, 'CHF');
    await tester.pump(); // request in flight

    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.88',
    );
    await tester.pump();
    gate.complete(); // the answer arrives second
    await tester.pumpAndSettle();

    expect(_rateText(tester), '0.88');
    expect(
      find.byKey(const ValueKey('expense_rate_prefill_date')),
      findsNothing,
    );
  });

  // AC: changing the date re-fetches for the new date.
  testWidgets(
    'changing the expense date refetches the prefill for the new date',
    (tester) async {
      final lookup = _StubLookup({
        '2026-07-01': RateQuote(
          rate: 0.9432,
          effectiveDate: DateTime(2026, 6, 30),
        ),
        ymd(_yesterday): RateQuote(rate: 0.9611, effectiveDate: _yesterday),
      });
      await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      expect(_rateText(tester), '0.9432');

      await _pickYesterday(tester);

      expect(lookup.calls.map(ymd).toList(), ['2026-07-01', ymd(_yesterday)]);
      expect(_rateText(tester), '0.9611');
    },
  );

  // AC: editing any other field never triggers a fetch and never changes a rate.
  testWidgets('editing another field neither refetches nor moves the rate', (
    tester,
  ) async {
    final lookup = _StubLookup({
      '2026-07-01': RateQuote(
        rate: 0.9432,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    });
    await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('expense_name_field')),
      'Hotel',
    );
    await tester.pumpAndSettle();

    expect(lookup.calls, hasLength(1));
    expect(_rateText(tester), '0.9432');
  });

  // AC: a saved expense's stored rate is never altered by this feature.
  testWidgets(
    'a saved converted expense is never refetched for, even on a date change',
    (tester) async {
      final lookup = _StubLookup({
        '2026-07-01': RateQuote(
          rate: 0.9999,
          effectiveDate: DateTime(2026, 6, 30),
        ),
        ymd(_yesterday): RateQuote(rate: 0.8888, effectiveDate: _yesterday),
      });
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        expense: convertedExpense(), // JPY 3000 @ 0.0058, rate_date 2026-08-16
        lookupRate: lookup.call,
      );
      await tester.pumpAndSettle();
      expect(lookup.calls, isEmpty);
      expect(_rateText(tester), '0.0058');

      await _pickYesterday(tester);
      expect(
        lookup.calls,
        isEmpty,
        reason: 'a frozen rate is never refetched for',
      );
      expect(_rateText(tester), '0.0058');

      await saveEditor(tester);
      expect(saved.single.conversion!.rate, 0.0058);
      expect(saved.single.conversion!.rateDate, '2026-08-16');
    },
  );

  // The dependency's sticky prefill is a rate the user typed; it outranks this.
  testWidgets('a remembered rate wins — no prefill is even requested', (
    tester,
  ) async {
    prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
    final lookup = _StubLookup({
      '2026-07-01': RateQuote(
        rate: 0.8000,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    });
    await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    expect(lookup.calls, isEmpty);
    expect(_rateText(tester), '0.9432');
  });

  // Accepting the suggestion untouched must leave nothing remembered —
  // otherwise the prefill becomes its own successor and the fetch fires once
  // per group and currency, ever.
  testWidgets('an accepted prefill is saved but never remembered', (
    tester,
  ) async {
    final lookup = _StubLookup({
      '2026-07-01': RateQuote(
        rate: 0.9432,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    });
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      lookupRate: lookup.call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();
    await saveEditor(tester);

    expect(saved.single.conversion!.rate, 0.9432);
    expect(prefsValues[kStickyRatesPrefKey], anyOf(isNull, contains('{}')));
  });

  testWidgets('a rate typed over the prefill IS remembered', (tester) async {
    final lookup = _StubLookup({
      '2026-07-01': RateQuote(
        rate: 0.9432,
        effectiveDate: DateTime(2026, 6, 30),
      ),
    });
    await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      lookupRate: lookup.call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.91',
    );
    await tester.pumpAndSettle();
    await saveEditor(tester);

    expect(jsonDecode(prefsValues[kStickyRatesPrefKey]!), {'g1|CHF': 0.91});
  });

  // AC: unreachable / no published rate => manual entry with a VISIBLE
  // explanation. Never 1:1, never today's rate in place of the asked-for date.
  testWidgets('an unavailable rate falls back to manual entry, visibly', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final lookup = _StubLookup(const {}); // nothing for any date
    await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();

    expect(lookup.calls, hasLength(1));
    expect(
      find.byKey(const ValueKey('expense_rate_unavailable')),
      findsOneWidget,
    );
    expect(find.text(l10n.expenseRateUnavailable), findsOneWidget);
    // No substituted rate of any kind, and the refusal-to-save hint still
    // stands.
    expect(_rateText(tester), '');
    expect(find.text(l10n.expenseRateRequired), findsOneWidget);
    expect(find.byKey(const ValueKey('expense_rate_preview')), findsNothing);
  });

  testWidgets(
    'an unavailable rate never blocks saving a manually entered one',
    (tester) async {
      final saved = await pumpEditorWithSaveSeam(
        tester,
        currencyCode: 'EUR',
        lookupRate: _StubLookup(const {}).call,
      );
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expense_rate_field')),
        '0.9432',
      );
      await tester.pumpAndSettle();
      await saveEditor(tester);

      expect(saved.single.conversion!.rate, 0.9432);
      expect(
        find.byKey(const ValueKey('expense_rate_unavailable')),
        findsNothing,
      );
    },
  );

  // The wrong-date substitution arrived at by omission: a failed REfetch must
  // clear the previous date's prefill, not leave it standing under the new date.
  testWidgets(
    'a failed refetch clears the stale prefill rather than misdating it',
    (tester) async {
      final lookup = _StubLookup({
        '2026-07-01': RateQuote(
          rate: 0.9432,
          effectiveDate: DateTime(2026, 6, 30),
        ),
        // Yesterday deliberately absent from the table.
      });
      await pumpEditor(tester, currencyCode: 'EUR', lookupRate: lookup.call);
      await pickCurrency(tester, 'CHF');
      await tester.pumpAndSettle();
      expect(_rateText(tester), '0.9432');

      await _pickYesterday(tester);

      expect(_rateText(tester), '');
      expect(
        find.byKey(const ValueKey('expense_rate_prefill_date')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('expense_rate_unavailable')),
        findsOneWidget,
      );
    },
  );

  // Half a precision fix is none: `formatRate` can now render ten decimals for
  // a small rate, but the field's input formatter decides whether one survives
  // being edited. Capped at six, touching a prefilled IDR rate would silently
  // round it back and reintroduce the 0.87% the fix removed.
  testWidgets('a small rate keeps its precision through the rate field', (
    tester,
  ) async {
    // IDR -> GBP, the weakest quote in kSupportedCurrencies into the strongest.
    const tiny = 0.0000494306;
    // Deliberately NO prefill, so the field starts empty. The formatter rejects
    // by reverting to the field's previous text — prefilling the same number
    // first would make a rejection indistinguishable from an acceptance.
    final saved = await pumpEditorWithSaveSeam(
      tester,
      currencyCode: 'EUR',
      lookupRate: _StubLookup(const {}).call,
    );
    await pickCurrency(tester, 'CHF');
    await tester.pumpAndSettle();
    expect(_rateText(tester), '');

    await tester.enterText(
      find.byKey(const ValueKey('expense_rate_field')),
      '0.0000494306',
    );
    await tester.pumpAndSettle();
    expect(
      _rateText(tester),
      '0.0000494306',
      reason: 'the input formatter must not round a small rate away',
    );

    await saveEditor(tester);
    expect(saved.single.conversion!.rate, closeTo(tiny, tiny * 0.00001));
  });

  test(
    'both new strings exist in both locales and the German is German',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      expect(en.expenseRatePrefilledOn('30 Jun'), 'Rate for 30 Jun');
      expect(de.expenseRatePrefilledOn('30 Jun'), 'Kurs vom 30 Jun');
      expect(de.expenseRateUnavailable, isNot(en.expenseRateUnavailable));
      expect(en.expenseRateUnavailable, contains('manually'));
      expect(de.expenseRateUnavailable, contains('manuell'));
    },
  );
}
