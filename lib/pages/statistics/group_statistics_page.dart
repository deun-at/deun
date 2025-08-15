import 'package:deun/helper/helper.dart';
import 'package:deun/provider.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:deun/pages/expenses/expense_category.dart';
import 'package:deun/pages/statistics/category_detail_bottom_sheet.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:intl/intl.dart';

class GroupStatisticsPage extends ConsumerStatefulWidget {
  const GroupStatisticsPage({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupStatisticsPage> createState() => _GroupStatisticsPageState();
}

class _GroupStatisticsPageState extends ConsumerState<GroupStatisticsPage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentChunkIndex = 0; // each page = 6 months chunk
  MonthBucket? _selectedMonth;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadChunk(int chunkIndex) {
    if (chunkIndex < 0) return; // prevent going into the future
    _currentChunkIndex = chunkIndex;
    final endOffset = chunkIndex * 6;
    ref.read(groupMonthlyTotalsNotifierProvider(widget.group.id).notifier).loadOffset(widget.group.id, endOffset);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupMonthlyTotalsNotifierProvider(widget.group.id));

    return Scaffold(
      appBar: AppBar(
        title: Text("Statistics", maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
        data: (data) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  surfaceTintColor: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            "${DateFormat("MMMM yyyy").format(_selectedMonth?.start ?? data.months.last.start)}: ${toCurrency(_selectedMonth?.total ?? data.months.last.total)}",
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(
                          height: 260,
                          child: PageView.builder(
                            reverse: true, // swipe the other direction for older months
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _selectedMonth = null; // reset selection for the new page
                              });
                              _loadChunk(index);
                            },
                            itemBuilder: (ctx, index) {
                              if (index != _currentChunkIndex || data.endOffsetMonths != index * 6) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final pageMonths = data.months;

                              return BarChart(
                                BarChartData(
                                  gridData: FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 || idx >= pageMonths.length) return SizedBox.shrink();
                                          final d = pageMonths[idx].start;
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(DateFormat("MMM").format(d)),
                                          );
                                        },
                                        reservedSize: 25,
                                      ),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        reservedSize: 50,
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          if (value == 0 || value >= meta.max) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(meta.formattedValue),
                                            );
                                          } else {
                                            return SizedBox.shrink();
                                          }
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(""),
                                          );
                                        },
                                        reservedSize: 10,
                                      ),
                                    ),
                                  ),
                                  barGroups: pageMonths.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final m = entry.value;
                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: m.total,
                                          width: 18,
                                          borderRadius: BorderRadius.circular(6),
                                          color: (_selectedMonth?.start ?? data.months.last.start) == m.start
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.primaryContainer,
                                        ),
                                      ],
                                      showingTooltipIndicators: [0],
                                    );
                                  }).toList(),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (groupData) => Colors.transparent,
                                      tooltipPadding: EdgeInsets.zero,
                                      tooltipMargin: 0,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          "",
                                          TextStyle(color: Colors.transparent),
                                        );
                                      },
                                    ),
                                    handleBuiltInTouches: true,
                                    touchCallback: (event, response) {
                                      if (response == null) return;
                                      // Only react to taps: ignore pans/drags
                                      if (!(event is FlTapUpEvent || event is FlLongPressEnd)) return;
                                      final spot = response.spot;
                                      if (spot == null) return;
                                      final bucket = pageMonths[spot.touchedBarGroupIndex];
                                      setState(() {
                                        _selectedMonth = bucket;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final selectedBucket = (() {
                    final currentMonths = data.months;
                    if (_selectedMonth == null) return currentMonths.last;
                    final match = currentMonths.where((b) => b.start == _selectedMonth!.start).toList();
                    return match.isEmpty ? currentMonths.last : match.first;
                  })();
                  final args = GroupMonthCategoryTotalsArgs(
                    groupId: widget.group.id,
                    monthStart: selectedBucket.start,
                    monthEnd: selectedBucket.end,
                  );
                  final detailsState = ref.watch(groupMonthCategoryTotalsNotifierProvider(args));
                  final localizations = AppLocalizations.of(context)!;

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    surfaceTintColor: Theme.of(context).colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Categories ${DateFormat("MMMM yyyy").format(selectedBucket.start)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          detailsState.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, st) => Text(e.toString()),
                            data: (list) {
                              if (list.isEmpty) {
                                return const Text('No expenses');
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = list[i];
                                  final category = ExpenseCategory.values.firstWhere(
                                    (c) => c.name == item.categoryName,
                                    orElse: () => ExpenseCategory.other,
                                  );
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      category.getIcon(),
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    title: Text(category.getDisplayName(localizations)),
                                    trailing: Text(toCurrency(item.total)),
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => DraggableScrollableSheet(
                                          initialChildSize: 0.5,
                                          minChildSize: 0.3,
                                          maxChildSize: 0.9,
                                          builder: (context, scrollController) => CategoryDetailBottomSheet(
                                            groupId: widget.group.id,
                                            categoryName: item.categoryName,
                                            monthStart: selectedBucket.start,
                                            monthEnd: selectedBucket.end,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
