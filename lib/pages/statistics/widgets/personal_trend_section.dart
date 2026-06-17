import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Monthly spend bars for the personal overview: your fair share per month,
/// themed like the group trend bars (E6-T1) and sharing its [labelStep] helper.
class PersonalTrendSection extends ConsumerWidget {
  const PersonalTrendSection({super.key, required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalStatisticsProvider(range));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final months = state.maybeWhen(
      data: (s) => s.monthlyTotals,
      orElse: () => const <MonthBucket>[],
    );
    if (months.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.statisticsTrend),
          const SizedBox(height: 8),
          SoftCard(
            child: SizedBox(
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
                        getTitlesWidget: (value, meta) => _bottomLabel(value, meta, months, theme),
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
                            width: 10,
                            borderRadius: BorderRadius.circular(4),
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _bottomLabel(double value, TitleMeta meta, List<MonthBucket> months, ThemeData theme) {
  final idx = value.toInt();
  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
  final step = labelStep(months.length);
  if (idx % step != 0 && idx != months.length - 1) return const SizedBox.shrink();
  return SideTitleWidget(
    meta: meta,
    child: Text(
      DateFormat('MMM').format(months[idx].start),
      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    ),
  );
}
