import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PersonalStatisticsPage extends ConsumerStatefulWidget {
  const PersonalStatisticsPage({super.key});

  @override
  ConsumerState<PersonalStatisticsPage> createState() => _PersonalStatisticsPageState();
}

class _PersonalStatisticsPageState extends ConsumerState<PersonalStatisticsPage> {
  StatsRange _range = StatsRange.sixMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(personalStatisticsProvider(_range));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statisticsPersonalOverviewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SegmentedButton<StatsRange>(
                    style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: StatsRange.threeMonths, label: Text(l10n.statisticsRangeThreeMonths)),
                      ButtonSegment(value: StatsRange.sixMonths, label: Text(l10n.statisticsRangeSixMonths)),
                      ButtonSegment(value: StatsRange.twelveMonths, label: Text(l10n.statisticsRangeTwelveMonths)),
                      ButtonSegment(value: StatsRange.allTime, label: Text(l10n.statisticsRangeAllTime)),
                    ],
                    selected: {_range},
                    onSelectionChanged: (set) => setState(() => _range = set.first),
                  ),
                ),
                state.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(e.toString()),
                  ),
                  data: (data) {
                    if (data.expenseCount == 0 && data.groups.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyLarge),
                        ),
                      );
                    }
                    final topGroup = data.groups.isNotEmpty ? data.groups.first : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCard(state: data, topGroup: topGroup),
                        _MonthlyTrend(months: data.monthlyTotals),
                        _GroupsRanked(groups: data.groups, total: data.totalShare),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state, required this.topGroup});
  final PersonalStatisticsState state;
  final PersonalGroupSummary? topGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statisticsTotalSpend, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                toCurrency(state.totalShare),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.statisticsMemberPaid, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(toCurrency(state.totalPaid),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.statisticsExpenseCount, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(state.expenseCount.toString(),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (topGroup != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.statisticsTopGroup, style: theme.textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Text(
                            topGroup!.groupName,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyTrend extends StatelessWidget {
  const _MonthlyTrend({required this.months});
  final List<MonthBucket> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (months.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statisticsTrend, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                            final step = (months.length / 6).ceil().clamp(1, months.length);
                            if (idx % step != 0 && idx != months.length - 1) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(DateFormat('MMM').format(months[idx].start),
                                  style: theme.textTheme.labelSmall),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: months[i].total,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsRanked extends StatelessWidget {
  const _GroupsRanked({required this.groups, required this.total});
  final List<PersonalGroupSummary> groups;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (groups.isEmpty) return const SizedBox.shrink();

    final maxVal = groups.fold<double>(0, (a, g) => g.totalShare > a ? g.totalShare : a);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statisticsGroupsRanked, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final g in groups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(g.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.groupName,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(toCurrency(g.totalShare),
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxVal > 0 ? (g.totalShare / maxVal).clamp(0.0, 1.0) : 0,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(Color(g.colorValue)),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

