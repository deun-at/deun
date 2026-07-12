import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/summary_section.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fix cosmetic-round-2026-07 (statistics card / landscape): opening the group
/// statistics screen in landscape must show the big statistics (summary) card
/// correctly aligned — no clipped or off-grid layout. These pump the big card
/// at a landscape size and assert it neither overflows nor drifts off the 16px
/// content grid the rest of the screen uses.
Future<void> _pumpSummary(
  WidgetTester tester,
  Size size, {
  SpendingSummary summary = const SpendingSummary(
    total: 1234.56,
    expenseCount: 42,
    avgPerMonth: 205.76,
    biggestExpense: 999.99,
    prevPeriodTotal: 1000,
    deltaPct: 23.4,
  ),
}) async {
  const args = StatsRangeArgs(groupId: 'g1', range: StatsRange.sixMonths);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupSpendingSummaryProvider(args).overrideWith((ref) async => summary),
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
            data: getThemeData(context, kBrandSeed, Brightness.light),
            child: const Scaffold(
              body: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: StatsSummarySection(args: args),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('summary card renders in landscape without overflow', (
    tester,
  ) async {
    // Wide, short surface — a typical phone landscape viewport.
    await _pumpSummary(tester, const Size(900, 400));

    // No RenderFlex overflow or other layout exception.
    expect(tester.takeException(), isNull);
    // The big card actually painted its total.
    expect(find.byType(StatsSummarySection), findsOneWidget);
  });

  testWidgets('summary card stays on the 16px content grid in landscape', (
    tester,
  ) async {
    const width = 900.0;
    await _pumpSummary(tester, const Size(width, 400));

    // The big statistics card is the single group-tinted rounded Container. Its
    // left and right edges must sit at the 16px content inset the rest of the
    // statistics screen uses — not clipped, not stretched off-grid.
    final cardFinder = find
        .descendant(
          of: find.byType(StatsSummarySection),
          matching: find.byType(Container),
        )
        .first;
    final box = tester.getRect(cardFinder);
    expect(box.left, moreOrLessEquals(16, epsilon: 0.5));
    expect(box.right, moreOrLessEquals(width - 16, epsilon: 0.5));
  });
}
