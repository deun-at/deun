import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/personal_groups_section.dart';
import 'package:deun/pages/statistics/widgets/personal_summary_section.dart';
import 'package:deun/pages/statistics/widgets/personal_trend_section.dart';
import 'package:deun/widgets/restyle/currency_breakdown_disclosure.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _months = [
  MonthBucket(
    start: DateTime(2026, 1, 1),
    end: DateTime(2026, 2, 1),
    total: 120,
  ),
  MonthBucket(
    start: DateTime(2026, 2, 1),
    end: DateTime(2026, 3, 1),
    total: 240,
  ),
  MonthBucket(
    start: DateTime(2026, 3, 1),
    end: DateTime(2026, 4, 1),
    total: 80,
  ),
];

const _groups = [
  PersonalGroupSummary(
    groupId: 'g1',
    groupName: 'Flat share',
    colorValue: 0xFF5750E6,
    currency: Currency.eur,
    totalPaid: 500,
    totalShare: 300,
    expenseCount: 6,
  ),
  PersonalGroupSummary(
    groupId: 'g2',
    groupName: 'Ski trip',
    colorValue: 0xFFD85A47,
    currency: Currency.eur,
    totalPaid: 100,
    totalShare: 140,
    expenseCount: 3,
  ),
];

final _state = PersonalStatisticsState(
  groups: _groups,
  monthlyTotalsByCurrency: {Currency.eur: _months},
  totalPaidByCurrency: {Currency.eur: 600},
  shareByCurrency: const CurrencyBreakdown(
    primary: CurrencyAmount(Currency.eur, 440),
  ),
  expenseCount: 9,
);

final _jpyMonths = [
  MonthBucket(
    start: DateTime(2026, 1, 1),
    end: DateTime(2026, 2, 1),
    total: 20000,
  ),
  MonthBucket(
    start: DateTime(2026, 2, 1),
    end: DateTime(2026, 3, 1),
    total: 25000,
  ),
  MonthBucket(
    start: DateTime(2026, 3, 1),
    end: DateTime(2026, 4, 1),
    total: 15000,
  ),
];

final _mixedState = PersonalStatisticsState(
  groups: const [
    PersonalGroupSummary(
      groupId: 'g1',
      groupName: 'Flat share',
      colorValue: 0xFF5750E6,
      currency: Currency.eur,
      totalPaid: 500,
      totalShare: 300,
      expenseCount: 6,
    ),
    PersonalGroupSummary(
      groupId: 'g2',
      groupName: 'Tokyo',
      colorValue: 0xFFD85A47,
      currency: Currency.jpy,
      totalPaid: 90000,
      totalShare: 60000,
      expenseCount: 3,
    ),
  ],
  monthlyTotalsByCurrency: {Currency.eur: _months, Currency.jpy: _jpyMonths},
  totalPaidByCurrency: {Currency.eur: 500, Currency.jpy: 90000},
  shareByCurrency: const CurrencyBreakdown(
    primary: CurrencyAmount(Currency.jpy, 60000),
    others: [CurrencyAmount(Currency.eur, 300)],
  ),
  expenseCount: 9,
);

class _FakePersonalStatisticsNotifier extends PersonalStatisticsNotifier {
  _FakePersonalStatisticsNotifier(this._state);
  final PersonalStatisticsState _state;

  @override
  FutureOr<PersonalStatisticsState> build(StatsRange range) => _state;
}

final _overrides = [
  personalStatisticsProvider(
    StatsRange.sixMonths,
  ).overrideWith(() => _FakePersonalStatisticsNotifier(_state)),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A currency selection already in view state when the surface first builds —
/// what a user carries over from another range.
class _FixedStatsCurrencyNotifier extends PersonalStatsCurrencyNotifier {
  _FixedStatsCurrencyNotifier(this._currency);
  final Currency _currency;

  @override
  Currency? build() => _currency;
}

Future<void> _pumpState(
  WidgetTester tester,
  Widget child, {
  required PersonalStatisticsState state,
  Currency? selectedCurrency,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalStatisticsProvider(
          StatsRange.sixMonths,
        ).overrideWith(() => _FakePersonalStatisticsNotifier(state)),
        if (selectedCurrency != null)
          personalStatsCurrencyProvider.overrideWith(
            () => _FixedStatsCurrencyNotifier(selectedCurrency),
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMixed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalStatisticsProvider(
          StatsRange.sixMonths,
        ).overrideWith(() => _FakePersonalStatisticsNotifier(_mixedState)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonalSummarySection (dark hero)', () {
    testWidgets(
      'F180: eyebrow + dual You-paid/Your-share amounts, share accent-tinted',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await _pump(
          tester,
          const PersonalSummarySection(range: StatsRange.sixMonths),
        );

        // Eyebrow: "Across all groups · last 6 months" (period reflects the range).
        expect(
          find.text(
            '${l10n.statisticsAcrossAllGroups} · ${l10n.statisticsPeriodLastMonths(6)}',
          ),
          findsOneWidget,
        );
        // Dual labels + amounts.
        expect(find.text(l10n.statisticsYouPaid), findsOneWidget);
        expect(find.text(l10n.statisticsYourShare), findsOneWidget);
        expect(find.text(l10n.toCurrency(600)), findsWidgets); // you paid
        expect(find.text(l10n.toCurrency(440)), findsWidgets); // your share

        // The share amount is tinted the accent (inversePrimary in light theme).
        final ctx = tester.element(find.byType(PersonalSummarySection));
        final scheme = Theme.of(ctx).colorScheme;
        final shareText = tester.widget<Text>(
          find.descendant(
            of: find.byType(MoneyText),
            matching: find.text(l10n.toCurrency(440)),
          ),
        );
        expect(shareText.style?.color, scheme.inversePrimary);

        await _pump(
          tester,
          const PersonalSummarySection(range: StatsRange.sixMonths),
          brightness: Brightness.dark,
        );
        expect(find.byType(MoneyText), findsWidgets);
      },
    );
  });

  group('PersonalTrendSection (monthly bars)', () {
    testWidgets('renders a SectionLabel and a BarChart', (tester) async {
      await _pump(
        tester,
        const PersonalTrendSection(range: StatsRange.sixMonths),
      );
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });

    // F177: mirror the F64 group-trend rule — only the latest month rod is
    // tinted the accent color; every other rod is the neutral track token.
    testWidgets('only the latest rod is primary; the rest are neutral track', (
      tester,
    ) async {
      await _pump(
        tester,
        const PersonalTrendSection(range: StatsRange.sixMonths),
      );

      final ctx = tester.element(find.byType(PersonalTrendSection));
      final scheme = Theme.of(ctx).colorScheme;

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final rodColors = chart.data.barGroups
          .map((g) => g.barRods.single.color)
          .toList();

      // _months has 3 entries; the last (index 2) is the latest.
      expect(rodColors[0], scheme.surfaceContainerHighest);
      expect(rodColors[1], scheme.surfaceContainerHighest);
      expect(
        rodColors[2],
        scheme.primary,
        reason: 'exactly the latest rod is tinted',
      );
    });
  });

  group('PersonalGroupsSection (by-group list)', () {
    testWidgets('renders each group name, its share, and a ProgressBar', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        const PersonalGroupsSection(range: StatsRange.sixMonths),
      );
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('Flat share'), findsOneWidget);
      expect(find.text('Ski trip'), findsOneWidget);
      expect(find.text(l10n.toCurrency(300)), findsOneWidget);
      expect(find.text(l10n.toCurrency(140)), findsOneWidget);
      expect(find.byType(ProgressBar), findsNWidgets(2));
    });
  });

  group('multi-currency personal statistics', () {
    testWidgets('single-currency stats show no currency selector', (
      tester,
    ) async {
      await _pump(
        tester,
        const PersonalSummarySection(range: StatsRange.sixMonths),
      );
      expect(find.byType(CurrencyBreakdownDisclosure), findsNothing);
    });

    testWidgets(
      'mixed-currency stats render the primary inline and disclose the rest',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await _pumpMixed(
          tester,
          const PersonalSummarySection(range: StatsRange.sixMonths),
        );
        // JPY has the largest absolute share, so it is the primary.
        expect(find.text('¥60,000'), findsOneWidget); // your share
        expect(find.text('¥90,000'), findsOneWidget); // you paid, same currency
        // Exactly two currencies means exactly one is hidden inline, and the
        // disclosure says one — selector mode changes the wording, never the
        // count, so it can list the primary too without overstating.
        expect(find.text(l10n.currencyBreakdownSelect(1)), findsOneWidget);
        expect(find.text(l10n.currencyBreakdownSelect(2)), findsNothing);
      },
    );

    testWidgets(
      'the trend chart defaults to the primary currency and labels its axis',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await _pumpMixed(
          tester,
          const PersonalTrendSection(range: StatsRange.sixMonths),
        );
        expect(find.text(l10n.statisticsTrendCurrency('JPY')), findsOneWidget);

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups.map((g) => g.barRods.single.toY).toList(), [
          20000.0,
          25000.0,
          15000.0,
        ]);
      },
    );

    testWidgets('each bucket sums the plotted currency ONLY — other currencies '
        'contribute nothing', (tester) async {
      await _pumpMixed(
        tester,
        const PersonalTrendSection(range: StatsRange.sixMonths),
      );
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      // The EUR buckets are 120/240/80. A folded-in series would show 20120 etc.
      for (final y in chart.data.barGroups.map((g) => g.barRods.single.toY)) {
        expect([20000.0, 25000.0, 15000.0], contains(y));
      }
    });

    testWidgets(
      'selecting another currency from the disclosure re-plots the chart',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        // Both sections in one tree so they share the ProviderScope view state.
        await _pumpMixed(
          tester,
          const Column(
            children: [
              PersonalSummarySection(range: StatsRange.sixMonths),
              PersonalTrendSection(range: StatsRange.sixMonths),
            ],
          ),
        );

        await tester.tap(find.text(l10n.currencyBreakdownSelect(1)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EUR'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.statisticsTrendCurrency('EUR')), findsOneWidget);
        final chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups.map((g) => g.barRods.single.toY).toList(), [
          120.0,
          240.0,
          80.0,
        ]);
      },
    );

    testWidgets('a single-currency user sees no chart selector', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            PersonalSummarySection(range: StatsRange.sixMonths),
            PersonalTrendSection(range: StatsRange.sixMonths),
          ],
        ),
      );
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('a per-group row renders in that group\'s own currency', (
      tester,
    ) async {
      await _pumpMixed(
        tester,
        const PersonalGroupsSection(range: StatsRange.sixMonths),
      );
      expect(find.text('€300.00'), findsOneWidget);
      expect(find.text('¥60,000'), findsOneWidget);
    });
  });

  // The currency selection is one piece of view state shared by every range, so
  // a currency picked under a mixed range can arrive at a range that has no
  // buckets for it — and if that range is single-currency the selector is gone
  // too, leaving no way back.
  group('a selection this range has no data for falls back to the primary', () {
    test('resolveCurrency keeps a currency the state actually has', () {
      expect(_mixedState.resolveCurrency(Currency.eur), Currency.eur);
      expect(_mixedState.resolveCurrency(Currency.jpy), Currency.jpy);
    });

    test('resolveCurrency falls back when the range has no such buckets', () {
      expect(_state.resolveCurrency(Currency.jpy), Currency.eur);
      expect(_state.resolveCurrency(null), Currency.eur);
    });

    testWidgets('the chart still renders, in the primary currency', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpState(
        tester,
        const PersonalTrendSection(range: StatsRange.sixMonths),
        state: _state, // EUR only
        selectedCurrency: Currency.jpy, // carried over from another range
      );

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text(l10n.statisticsTrendCurrency('EUR')), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.map((g) => g.barRods.single.toY).toList(), [
        120.0,
        240.0,
        80.0,
      ]);
    });

    testWidgets('the hero marks the row the chart is actually plotting', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpState(
        tester,
        const PersonalSummarySection(range: StatsRange.sixMonths),
        state: _mixedState,
        // USD is in neither range; the primary (JPY) is marked instead.
        selectedCurrency: Currency.usd,
      );

      await tester.tap(find.text(l10n.currencyBreakdownSelect(1)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('JPY')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('EUR')).style?.fontWeight,
        FontWeight.w500,
      );
    });
  });

  // A group the user only ever paid for others in nets a ~0 share. A balance
  // fold drops it; a spending fold must not, or its "you paid" total and its
  // whole trend series become unreachable.
  group('a currency the user only paid in stays in the breakdown', () {
    test('personalShareByCurrency keeps a zero-share currency', () {
      final b = personalShareByCurrency(const [
        CurrencyAmount(Currency.eur, 300),
        CurrencyAmount(Currency.jpy, 0),
      ]);
      expect(b.primary, const CurrencyAmount(Currency.eur, 300));
      expect(b.others, const [CurrencyAmount(Currency.jpy, 0)]);
      expect(b.isSingleCurrency, isFalse);
    });

    testWidgets('it stays in the selector, so its trend series is reachable', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final paidOnly = PersonalStatisticsState(
        groups: const [],
        monthlyTotalsByCurrency: {
          Currency.eur: _months,
          Currency.jpy: _jpyMonths,
        },
        totalPaidByCurrency: {Currency.eur: 500, Currency.jpy: 90000},
        shareByCurrency: personalShareByCurrency(const [
          CurrencyAmount(Currency.eur, 300),
          CurrencyAmount(Currency.jpy, 0),
        ]),
        expenseCount: 9,
      );

      await _pumpState(
        tester,
        const Column(
          children: [
            PersonalSummarySection(range: StatsRange.sixMonths),
            PersonalTrendSection(range: StatsRange.sixMonths),
          ],
        ),
        state: paidOnly,
      );

      await tester.tap(find.text(l10n.currencyBreakdownSelect(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.statisticsTrendCurrency('JPY')), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.map((g) => g.barRods.single.toY).toList(), [
        20000.0,
        25000.0,
        15000.0,
      ]);
    });
  });
}
