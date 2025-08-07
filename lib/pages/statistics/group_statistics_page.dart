import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/statistics_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../groups/group_model.dart';

class GroupStatisticsPage extends ConsumerStatefulWidget {
  const GroupStatisticsPage({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupStatisticsPage> createState() => _GroupStatisticsPageState();
}

class _GroupStatisticsPageState extends ConsumerState<GroupStatisticsPage> {
  int selectedMonthsBack = 6;
  Set<String> selectedMembers = {};
  bool showAllMembers = true;

  @override
  void initState() {
    super.initState();
    // Initialize with all members selected
    selectedMembers = widget.group.groupMembers.map((m) => m.email).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final statisticsState = ref.watch(groupStatisticsNotifierProvider(widget.group.id, monthsBack: selectedMonthsBack));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statistics),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          PopupMenuButton<int>(
            onSelected: (months) {
              setState(() {
                selectedMonthsBack = months;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 3, child: Text(AppLocalizations.of(context)!.lastMonths(3))),
              PopupMenuItem(value: 6, child: Text(AppLocalizations.of(context)!.lastMonths(6))),
              PopupMenuItem(value: 12, child: Text(AppLocalizations.of(context)!.lastMonths(12))),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context)!.lastMonths(selectedMonthsBack)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: statisticsState.when(
        data: (statistics) => _buildStatisticsContent(context, statistics),
        loading: () => const Center(child: ShimmerCardList(height: 200, listEntryLength: 3)),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.errorLoadingData,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.refresh(groupStatisticsNotifierProvider(widget.group.id, monthsBack: selectedMonthsBack)),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsContent(BuildContext context, StatisticsData statistics) {
    if (statistics.monthlySpending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noExpenseData,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noExpenseDataDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMemberFilterCard(context, statistics),
          const SizedBox(height: 16),
          _buildMonthlyTrendCard(context, statistics),
          const SizedBox(height: 16),
          _buildMemberComparisonCard(context, statistics),
          const SizedBox(height: 16),
          _buildSummaryCard(context, statistics),
        ],
      ),
    );
  }

  Widget _buildMemberFilterCard(BuildContext context, StatisticsData statistics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.filterMembers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (showAllMembers) {
                        selectedMembers.clear();
                        showAllMembers = false;
                      } else {
                        selectedMembers = widget.group.groupMembers.map((m) => m.email).toSet();
                        showAllMembers = true;
                      }
                    });
                  },
                  child: Text(showAllMembers
                      ? AppLocalizations.of(context)!.selectNone
                      : AppLocalizations.of(context)!.selectAll),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: widget.group.groupMembers.map((member) {
                final isSelected = selectedMembers.contains(member.email);
                return FilterChip(
                  label: Text(member.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedMembers.add(member.email);
                      } else {
                        selectedMembers.remove(member.email);
                      }
                      showAllMembers = selectedMembers.length == widget.group.groupMembers.length;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendCard(BuildContext context, StatisticsData statistics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.monthlyTrend,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildLineChart(context, statistics),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberComparisonCard(BuildContext context, StatisticsData statistics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.memberComparison,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildBarChart(context, statistics),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, StatisticsData statistics) {
    final filteredTotalSpending = statistics.totalSpendingByMember.entries
        .where((entry) => selectedMembers.contains(entry.key))
        .fold(0.0, (sum, entry) => sum + entry.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              context,
              AppLocalizations.of(context)!.totalSpending,
              toCurrency(filteredTotalSpending),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              context,
              AppLocalizations.of(context)!.averagePerMonth,
              toCurrency(filteredTotalSpending / selectedMonthsBack),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              context,
              AppLocalizations.of(context)!.selectedMembers,
              '${selectedMembers.length} of ${widget.group.groupMembers.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, StatisticsData statistics) {
    final filteredData = _getFilteredMonthlyData(statistics);

    if (filteredData.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noDataToDisplay,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    // Group data by month and sum for selected members
    final monthlyTotals = <String, double>{};
    for (final spending in filteredData) {
      monthlyTotals[spending.month] = (monthlyTotals[spending.month] ?? 0) + spending.totalSpent;
    }

    final sortedMonths = monthlyTotals.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedMonths.length; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyTotals[sortedMonths[i]]!));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // Disable vertical grid lines to avoid label confusion
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // Show label for every month
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                // Only show labels for whole number values to avoid duplicates
                if (value != index.toDouble()) return const SizedBox.shrink();

                if (index >= 0 && index < sortedMonths.length) {
                  final date = DateTime.parse(sortedMonths[index]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('MMM').format(date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  AppLocalizations.of(context)!.toCurrencyShort(value),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final monthIndex = barSpot.x.toInt();
                if (monthIndex >= 0 && monthIndex < sortedMonths.length) {
                  final date = DateTime.parse(sortedMonths[monthIndex]);
                  final monthName = DateFormat('MMM yyyy').format(date);
                  final amount = toCurrency(barSpot.y);

                  return LineTooltipItem(
                    '$monthName\n$amount',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            // Handle touch events if needed
          },
          handleBuiltInTouches: true,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, StatisticsData statistics) {
    final memberTotals = <String, double>{};
    final filteredData = _getFilteredMonthlyData(statistics);

    for (final spending in filteredData) {
      memberTotals[spending.displayName] = (memberTotals[spending.displayName] ?? 0) + spending.totalSpent;
    }

    if (memberTotals.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noDataToDisplay,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final sortedEntries = memberTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final barGroups = <BarChartGroupData>[];
    final colors = _generateMemberColors(sortedEntries.length, context);

    for (int i = 0; i < sortedEntries.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sortedEntries[i].value,
              color: colors[i],
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: sortedEntries.isNotEmpty ? sortedEntries.first.value * 1.2 : 100,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedEntries[index].key,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  AppLocalizations.of(context)!.toCurrencyShort(value),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Theme.of(context).colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex >= 0 && groupIndex < sortedEntries.length) {
                final memberName = sortedEntries[groupIndex].key;
                final amount = toCurrency(rod.toY);

                return BarTooltipItem(
                  '$memberName\n$amount',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }
              return null;
            },
          ),
          touchCallback: (FlTouchEvent event, BarTouchResponse? touchResponse) {
            // Handle touch events if needed
          },
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  List<MonthlySpending> _getFilteredMonthlyData(StatisticsData statistics) {
    return statistics.monthlySpending.where((spending) => selectedMembers.contains(spending.email)).toList();
  }

  List<Color> _generateMemberColors(int count, BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.primary;
    final colors = <Color>[];

    for (int i = 0; i < count; i++) {
      final hue = (baseColor.computeLuminance() * 360 + (i * 360 / count)) % 360;
      colors.add(HSVColor.fromAHSV(1.0, hue, 0.7, 0.8).toColor());
    }

    return colors;
  }
}
