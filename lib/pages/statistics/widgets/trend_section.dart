import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StatsTrendSection extends ConsumerWidget {
  const StatsTrendSection({super.key, required this.args, required this.onMonthTap});
  final StatsRangeArgs args;
  final ValueChanged<MonthBucket> onMonthTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupTrendProvider(args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statisticsTrend, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: state.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (months) {
                    if (months.isEmpty) {
                      return Center(
                        child: Text(l10n.statisticsNoExpenses,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                      );
                    }
                    return months.length > 12
                        ? _TrendBars(months: months, onMonthTap: onMonthTap)
                        : _TrendLine(months: months, onMonthTap: onMonthTap);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.months, required this.onMonthTap});
  final List<MonthBucket> months;
  final ValueChanged<MonthBucket> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = [for (int i = 0; i < months.length; i++) FlSpot(i.toDouble(), months[i].total)];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final bucket = months[s.x.toInt()];
              return LineTooltipItem(
                '${DateFormat('MMM yyyy').format(bucket.start)}\n${toCurrency(bucket.total)}',
                theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onInverseSurface),
              );
            }).toList(),
          ),
          touchCallback: (event, response) {
            if (!(event is FlTapUpEvent || event is FlLongPressEnd)) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final idx = spots.first.x.toInt();
            if (idx >= 0 && idx < months.length) onMonthTap(months[idx]);
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3.5,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.35),
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.months, required this.onMonthTap});
  final List<MonthBucket> months;
  final ValueChanged<MonthBucket> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BarChart(
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
              getTitlesWidget: (value, meta) => _bottomLabel(value, meta, months, theme, withYear: true),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!(event is FlTapUpEvent || event is FlLongPressEnd)) return;
            final spot = response?.spot;
            if (spot == null) return;
            final idx = spot.touchedBarGroupIndex;
            if (idx >= 0 && idx < months.length) onMonthTap(months[idx]);
          },
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
    );
  }
}

Widget _bottomLabel(double value, TitleMeta meta, List<MonthBucket> months, ThemeData theme,
    {bool withYear = false}) {
  final idx = value.toInt();
  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
  final step = (months.length / 6).ceil().clamp(1, months.length);
  if (idx % step != 0 && idx != months.length - 1) return const SizedBox.shrink();
  return SideTitleWidget(
    meta: meta,
    child: Text(
      DateFormat(withYear ? 'MMM yy' : 'MMM').format(months[idx].start),
      style: theme.textTheme.labelSmall,
    ),
  );
}
