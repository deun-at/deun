import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/categories_section.dart';
import 'package:deun/pages/statistics/widgets/members_section.dart';
import 'package:deun/pages/statistics/widgets/summary_section.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _args = StatsRangeArgs(groupId: 'g1', range: StatsRange.sixMonths);

const _summary = SpendingSummary(
  total: 1200,
  expenseCount: 8,
  avgPerMonth: 200,
  biggestExpense: 350,
  prevPeriodTotal: 1000,
  deltaPct: 20,
);

const _members = [
  MemberSpendingBreakdown(
    email: 'a@x', displayName: 'Ann Lee', paid: 700, fairShare: 600, pctOfTotal: 58),
  MemberSpendingBreakdown(
    email: 'b@x', displayName: 'Bob Roy', paid: 500, fairShare: 600, pctOfTotal: 42),
];

const _categories = [
  CategoryMonthTotal(categoryName: 'food', categoryDisplayName: 'food', total: 800),
  CategoryMonthTotal(categoryName: 'travel', categoryDisplayName: 'travel', total: 400),
];

final _overrides = [
  groupSpendingSummaryProvider.overrideWith((ref, StatsRangeArgs args) async => _summary),
  groupTrendProvider.overrideWith((ref, StatsRangeArgs args) async => const <MonthBucket>[]),
  groupMemberBreakdownProvider.overrideWith((ref, StatsRangeArgs args) async => _members),
  groupCategoryBreakdownProvider.overrideWith((ref, StatsRangeArgs args) async => _categories),
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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
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

  group('StatsSummarySection (restyle)', () {
    testWidgets('renders the total via MoneyText in light and dark', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, const StatsSummarySection(args: _args));
      expect(find.byType(MoneyText), findsWidgets);
      expect(find.text(l10n.toCurrency(1200)), findsWidgets);

      await _pump(tester, const StatsSummarySection(args: _args),
          brightness: Brightness.dark);
      expect(find.byType(MoneyText), findsWidgets);
    });

    testWidgets('shows the avg / count / biggest mini stats', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, const StatsSummarySection(args: _args));
      expect(find.text(l10n.statisticsAvgPerMonth), findsOneWidget);
      expect(find.text(l10n.statisticsExpenseCount), findsOneWidget);
      expect(find.text(l10n.statisticsBiggestExpense), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });
  });

  group('StatsMembersSection (restyle)', () {
    testWidgets('renders a SectionLabel and each member name', (tester) async {
      await _pump(tester, const StatsMembersSection(args: _args));
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('Bob Roy'), findsOneWidget);
    });
  });

  group('StatsCategoriesSection (restyle)', () {
    testWidgets('tapping a category bar fires onCategoryTap with its name',
        (tester) async {
      String? tapped;
      await _pump(
        tester,
        StatsCategoriesSection(
          args: _args,
          onCategoryTap: (name) => tapped = name,
        ),
      );
      // Tap the first category row (food).
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(tapped, 'food');
    });

    testWidgets('renders a SectionLabel header', (tester) async {
      await _pump(
        tester,
        StatsCategoriesSection(args: _args, onCategoryTap: (_) {}),
      );
      expect(find.byType(SectionLabel), findsOneWidget);
    });
  });

  group('range control', () {
    testWidgets('AppSegmentedControl switches range', (tester) async {
      StatsRange selected = StatsRange.sixMonths;
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
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
                data: getThemeData(context, kBrandSeed, Brightness.light)
                    .copyWith(splashFactory: NoSplash.splashFactory),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => AppSegmentedControl<StatsRange>(
                      value: selected,
                      segments: [
                        AppSegment(
                            value: StatsRange.threeMonths,
                            label: l10n.statisticsRangeThreeMonths),
                        AppSegment(
                            value: StatsRange.sixMonths,
                            label: l10n.statisticsRangeSixMonths),
                        AppSegment(
                            value: StatsRange.twelveMonths,
                            label: l10n.statisticsRangeTwelveMonths),
                        AppSegment(
                            value: StatsRange.allTime,
                            label: l10n.statisticsRangeAllTime),
                      ],
                      onChanged: (v) => setState(() => selected = v),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.statisticsRangeTwelveMonths));
      await tester.pumpAndSettle();
      expect(selected, StatsRange.twelveMonths);
    });
  });
}
