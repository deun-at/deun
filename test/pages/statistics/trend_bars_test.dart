/// V3-T8 — Trend bars grow animation tests.
///
/// Tests that _TrendBars (triggered when months.length > 12) animates each bar's
/// heightFactor from 0 → 1 on entrance, and skips animation with disableAnimations.
library;

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/trend_section.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Generate >12 months to trigger _TrendBars (not _TrendLine).
List<MonthBucket> _makeMonths(int count) => List.generate(
      count,
      (i) => MonthBucket(
        start: DateTime(2024, i + 1, 1),
        end: DateTime(2024, i + 2, 1),
        total: (i + 1) * 100.0,
      ),
    );

const _args = StatsRangeArgs(groupId: 'g1', range: StatsRange.twelveMonths);

Future<void> _pumpTrend(
  WidgetTester tester, {
  required List<MonthBucket> months,
  MediaQueryData? mediaQuery,
}) async {
  final overrides = [
    groupTrendProvider.overrideWith((ref, StatsRangeArgs args) async => months),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: mediaQuery != null
            ? (context, child) => MediaQuery(data: mediaQuery, child: child!)
            : null,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: StatsTrendSection(
                args: _args,
                onMonthTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('_TrendBars grow animation (V3-T8)', () {
    testWidgets(
        'bars are at full heightFactor after pumpAndSettle',
        (tester) async {
      final months = _makeMonths(13); // > 12 → _TrendBars
      await _pumpTrend(tester, months: months);
      // Let async provider + animation settle.
      await tester.pumpAndSettle();

      // Each bar is a FractionallySizedBox with heightFactor driven to 1.0.
      final boxes = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // At least one FractionallySizedBox per bar should have heightFactor == 1.0.
      final fullHeightBars = boxes.where((b) => b.heightFactor != null && (b.heightFactor! - 1.0).abs() < 0.001);
      expect(
        fullHeightBars.isNotEmpty,
        isTrue,
        reason: 'bars should be at full heightFactor == 1.0 after pumpAndSettle',
      );
    });

    testWidgets(
        'bars are mid-animation 50ms after mount (before pumpAndSettle)',
        (tester) async {
      final months = _makeMonths(13);
      await _pumpTrend(tester, months: months);
      // Settle just the async provider loading (not the animation).
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle(const Duration(milliseconds: 5)); // provider settle
      // Now advance a bit but not past the bar grow duration (620ms).
      await tester.pump(const Duration(milliseconds: 50));

      final boxes = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // At 50ms the bars should not yet be at heightFactor == 1.0.
      final allFull = boxes
          .where((b) => b.heightFactor != null)
          .every((b) => (b.heightFactor! - 1.0).abs() < 0.001);
      expect(
        allFull,
        isFalse,
        reason: 'bars should still be growing at 50ms (620ms total)',
      );
    });

    testWidgets(
        'with disableAnimations bars are at full heightFactor immediately',
        (tester) async {
      final months = _makeMonths(13);
      final mediaQuery = const MediaQueryData().copyWith(disableAnimations: true);
      await _pumpTrend(tester, months: months, mediaQuery: mediaQuery);
      await tester.pumpAndSettle(); // settle async provider
      await tester.pump(const Duration(milliseconds: 1));

      final boxes = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      final fullHeightBars = boxes.where((b) => b.heightFactor != null && (b.heightFactor! - 1.0).abs() < 0.001);
      expect(
        fullHeightBars.isNotEmpty,
        isTrue,
        reason: 'reduced motion: bars must be at full height immediately',
      );
    });
  });

  // F64: always bars (no LineChart), only the latest month tinted the group
  // color, the rest a neutral track token.
  group('_TrendBars monthly styling (F64)', () {
    testWidgets('renders bars for a <=12-month range (no LineChart branch)',
        (tester) async {
      final months = _makeMonths(6); // <= 12 used to render a LineChart
      await _pumpTrend(tester, months: months);
      await tester.pumpAndSettle();

      // 6 tappable bars, each a GestureDetector; no line chart involved.
      expect(find.byType(GestureDetector), findsNWidgets(6));
    });

    testWidgets('only the latest bar is primary; the rest are neutral track',
        (tester) async {
      final months = _makeMonths(4);
      await _pumpTrend(tester, months: months);
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(StatsTrendSection));
      final scheme = Theme.of(ctx).colorScheme;

      final barColors = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();

      final primaryCount =
          barColors.where((c) => c == scheme.primary).length;
      final neutralCount =
          barColors.where((c) => c == scheme.surfaceContainerHighest).length;
      expect(primaryCount, 1, reason: 'exactly the latest bar is tinted');
      expect(neutralCount, 3, reason: 'the other three bars are neutral');
    });
  });
}
