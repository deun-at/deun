import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Category breakdown: a themed donut (sliced by [ExpenseCategory.getColor]) plus
/// a list of per-category bars. Tapping a row opens the category detail sheet.
class StatsCategoriesSection extends ConsumerStatefulWidget {
  const StatsCategoriesSection({
    super.key,
    required this.args,
    required this.onCategoryTap,
  });

  final StatsRangeArgs args;
  final void Function(String categoryName) onCategoryTap;

  @override
  ConsumerState<StatsCategoriesSection> createState() => _StatsCategoriesSectionState();
}

class _StatsCategoriesSectionState extends ConsumerState<StatsCategoriesSection> {
  int? _touchedIdx;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCategoryBreakdownProvider(widget.args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.statisticsCategoryBreakdown),
          const SizedBox(height: 8),
          SoftCard(
            child: state.when(
              loading: () => const ShimmerCardList(height: 56, listEntryLength: 3),
              error: (e, _) => Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium),
              data: (list) {
                if (list.isEmpty) {
                  return Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium);
                }
                final total = list.fold<double>(0, (a, c) => a + c.total);
                final categories = [
                  for (final c in list)
                    ExpenseCategory.values.firstWhere(
                      (e) => e.name == c.categoryName,
                      orElse: () => ExpenseCategory.other,
                    ),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 176,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              startDegreeOffset: -90,
                              sectionsSpace: 2,
                              centerSpaceRadius: 56,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    _touchedIdx = response?.touchedSection?.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: [
                                for (int i = 0; i < list.length; i++)
                                  PieChartSectionData(
                                    value: list[i].total,
                                    color: categories[i].getColor(context),
                                    radius: _touchedIdx == i ? 30 : 24,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MoneyText(
                                total,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(l10n.statisticsTotalSpend,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < list.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: _CategoryRow(
                          category: categories[i],
                          total: list[i].total,
                          fraction: barFraction(list[i].total, total),
                          pct: percentOfTotal(list[i].total, total),
                          onTap: () => widget.onCategoryTap(list[i].categoryName),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.total,
    required this.fraction,
    required this.pct,
    required this.onTap,
  });

  final ExpenseCategory category;
  final double total;
  final double fraction;
  final double pct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = category.getColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.getIcon(), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.getDisplayName(l10n),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MoneyText(
                        total,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: ProgressBar(value: fraction, fillColor: color, height: 6)),
                      const SizedBox(width: 8),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
