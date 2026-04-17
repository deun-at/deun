import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsCategoriesSection extends ConsumerStatefulWidget {
  const StatsCategoriesSection({
    super.key,
    required this.args,
    required this.onCategoryTap,
  });

  final StatsRangeArgs args;
  final void Function(String categoryName) onCategoryTap;

  @override
  ConsumerState<StatsCategoriesSection> createState() =>
      _StatsCategoriesSectionState();
}

class _StatsCategoriesSectionState
    extends ConsumerState<StatsCategoriesSection> {
  int? _touchedIdx;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCategoryBreakdownProvider(widget.args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.statisticsCategoryBreakdown,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 10),
            state.when(
              loading: () =>
                  const ShimmerCardList(height: 56, listEntryLength: 3),
              error: (e, _) => Text(e.toString()),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    l10n.statisticsNoExpenses,
                    style: theme.textTheme.bodyMedium,
                  );
                }
                final total = list.fold<double>(0, (a, c) => a + c.total);
                final colors = _palette(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              startDegreeOffset: -90,
                              sectionsSpace: 2,
                              centerSpaceRadius: 55,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    _touchedIdx = response
                                        ?.touchedSection
                                        ?.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: [
                                for (int i = 0; i < list.length; i++)
                                  PieChartSectionData(
                                    value: list[i].total,
                                    color: colors[i % colors.length],
                                    radius: _touchedIdx == i ? 32 : 26,
                                    title: '',
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                toCurrency(total),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                l10n.statisticsTotalSpend,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CardListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final item = list[i];
                        final category = ExpenseCategory.values.firstWhere(
                          (c) => c.name == item.categoryName,
                          orElse: () => ExpenseCategory.other,
                        );
                        final pct = total > 0
                            ? (item.total / total * 100)
                            : 0.0;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length].withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category.getIcon(),
                              color: colors[i % colors.length],
                              size: 20,
                            ),
                          ),
                          title: Text(category.getDisplayName(l10n)),
                          subtitle: Text('${pct.toStringAsFixed(1)}%'),
                          trailing: Text(
                            toCurrency(item.total),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => widget.onCategoryTap(item.categoryName),
                        );
                      },
                    ),
                    SizedBox(height: 10),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _palette(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      Colors.amber.shade600,
      Colors.teal.shade400,
      Colors.deepPurple.shade300,
      Colors.redAccent.shade100,
      Colors.blueGrey.shade400,
    ];
  }
}
