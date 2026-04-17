import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsSummarySection extends ConsumerWidget {
  const StatsSummarySection({super.key, required this.args});
  final StatsRangeArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupSpendingSummaryProvider(args));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final showDelta = args.range != StatsRange.allTime;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: state.when(
            loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(e.toString()),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.statisticsTotalSpend, style: theme.textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(
                            toCurrency(s.total),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showDelta && s.prevPeriodTotal > 0) _DeltaChip(deltaPct: s.deltaPct),
                  ],
                ),
                if (showDelta && s.prevPeriodTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.statisticsVsPreviousPeriod,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _MiniStat(label: l10n.statisticsAvgPerMonth, value: toCurrency(s.avgPerMonth))),
                    Expanded(child: _MiniStat(label: l10n.statisticsExpenseCount, value: s.expenseCount.toString())),
                    Expanded(child: _MiniStat(label: l10n.statisticsBiggestExpense, value: toCurrency(s.biggestExpense))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.deltaPct});
  final double deltaPct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = deltaPct >= 0;
    final color = isUp ? theme.colorScheme.error : Colors.green.shade700;
    final bg = (isUp ? theme.colorScheme.error : Colors.green).withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${isUp ? '+' : ''}${deltaPct.toStringAsFixed(1)}%',
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
