import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/personal_groups_section.dart';
import 'package:deun/pages/statistics/widgets/personal_summary_section.dart';
import 'package:deun/pages/statistics/widgets/personal_trend_section.dart';
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
  MonthBucket(start: DateTime(2026, 1, 1), end: DateTime(2026, 2, 1), total: 120),
  MonthBucket(start: DateTime(2026, 2, 1), end: DateTime(2026, 3, 1), total: 240),
  MonthBucket(start: DateTime(2026, 3, 1), end: DateTime(2026, 4, 1), total: 80),
];

const _groups = [
  PersonalGroupSummary(
    groupId: 'g1',
    groupName: 'Flat share',
    colorValue: 0xFF5750E6,
    totalPaid: 500,
    totalShare: 300,
    expenseCount: 6,
  ),
  PersonalGroupSummary(
    groupId: 'g2',
    groupName: 'Ski trip',
    colorValue: 0xFFD85A47,
    totalPaid: 100,
    totalShare: 140,
    expenseCount: 3,
  ),
];

final _state = PersonalStatisticsState(
  groups: _groups,
  monthlyTotals: _months,
  totalPaid: 600,
  totalShare: 440,
  expenseCount: 9,
);

class _FakePersonalStatisticsNotifier extends PersonalStatisticsNotifier {
  _FakePersonalStatisticsNotifier(this._state);
  final PersonalStatisticsState _state;

  @override
  FutureOr<PersonalStatisticsState> build(StatsRange range) => _state;
}

final _overrides = [
  personalStatisticsProvider(StatsRange.sixMonths)
      .overrideWith(() => _FakePersonalStatisticsNotifier(_state)),
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

  group('PersonalSummarySection (dark hero)', () {
    testWidgets('shows the share total and paid via MoneyText in light and dark',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, const PersonalSummarySection(range: StatsRange.sixMonths));
      expect(find.byType(MoneyText), findsWidgets);
      expect(find.text(l10n.toCurrency(440)), findsWidgets); // total share (hero amount)
      expect(find.text(l10n.toCurrency(600)), findsWidgets); // total paid (sub-stat)
      expect(find.text('9'), findsOneWidget); // expense count

      await _pump(tester, const PersonalSummarySection(range: StatsRange.sixMonths),
          brightness: Brightness.dark);
      expect(find.byType(MoneyText), findsWidgets);
    });
  });

  group('PersonalTrendSection (monthly bars)', () {
    testWidgets('renders a SectionLabel and a BarChart', (tester) async {
      await _pump(tester, const PersonalTrendSection(range: StatsRange.sixMonths));
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });
  });

  group('PersonalGroupsSection (by-group list)', () {
    testWidgets('renders each group name, its share, and a ProgressBar',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, const PersonalGroupsSection(range: StatsRange.sixMonths));
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('Flat share'), findsOneWidget);
      expect(find.text('Ski trip'), findsOneWidget);
      expect(find.text(l10n.toCurrency(300)), findsOneWidget);
      expect(find.text(l10n.toCurrency(140)), findsOneWidget);
      expect(find.byType(ProgressBar), findsNWidgets(2));
    });
  });
}
