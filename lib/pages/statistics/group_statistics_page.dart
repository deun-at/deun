import 'package:deun/helper/helper.dart';
import 'package:deun/provider.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupStatisticsPage extends ConsumerStatefulWidget {
  const GroupStatisticsPage({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupStatisticsPage> createState() => _GroupStatisticsPageState();
}

class _GroupStatisticsPageState extends ConsumerState<GroupStatisticsPage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentChunkIndex = 0; // each page = 6 months chunk

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
        title: Text(widget.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
        data: (data) {
          // Static page layout; only the chart area is swipeable in 6-month steps
          final months = data.months;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Monthly expenses', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  surfaceTintColor: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 260,
                          child: PageView.builder(
                            reverse: true, // swipe the other direction for older months
                            controller: _pageController,
                            onPageChanged: (index) {
                              _loadChunk(index);
                            },
                            itemBuilder: (ctx, index) {
                              if (index != _currentChunkIndex || data.endOffsetMonths != index * 6) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final pageMonths = data.months;
                              final maxY = pageMonths.fold<double>(0, (acc, m) => m.total > acc ? m.total : acc);

                              return BarChart(
                                BarChartData(
                                  gridData: FlGridData(show: true, drawVerticalLine: false),
                                  borderData: FlBorderData(show: false),
                                  maxY: maxY == 0 ? 100 : maxY * 1.2,
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 || idx >= pageMonths.length) return const SizedBox.shrink();
                                          final d = pageMonths[idx].start;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text('${d.month.toString().padLeft(2, '0')}/${d.year % 100}'),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 44,
                                        getTitlesWidget: (value, meta) {
                                          return Text(toCurrency(value.toDouble()));
                                        },
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    handleBuiltInTouches: true,
                                    touchCallback: (event, response) {
                                      if (!event.isInterestedForInteractions || response == null) return;
                                      final spot = response.spot;
                                      if (spot == null) return;
                                      final bucket = pageMonths[spot.touchedBarGroupIndex];
                                      GoRouter.of(context).push('/group/details/statistics/month', extra: {
                                        'group': widget.group,
                                        'monthStart': bucket.start,
                                        'monthEnd': bucket.end,
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '${months.first.start.month.toString().padLeft(2, '0')}/${months.first.start.year % 100} - ${months.last.start.month.toString().padLeft(2, '0')}/${months.last.start.year % 100}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
