import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Group-tinted color summary hero: total spend (large), an optional Δ chip vs
/// the previous period, and a row of mini stats (avg / count / biggest).
///
/// The surrounding [ThemeBuilder] has already re-tinted the theme by the
/// group's color, so the hero surface comes from `colorScheme.primary*`.
class StatsSummarySection extends ConsumerWidget {
  const StatsSummarySection({super.key, required this.args});
  final StatsRangeArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupSpendingSummaryProvider(args));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showDelta = args.range != StatsRange.allTime;

    final Color heroSurface = isDark ? theme.colorScheme.primaryContainer : theme.colorScheme.primary;
    final Color onHero = isDark ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onPrimary;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: heroSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: state.when(
          loading: () => const SizedBox(
            height: 130,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 130,
            child: Center(
              child: Text(l10n.statisticsNoExpenses, style: TextStyle(color: onHeroMuted)),
            ),
          ),
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
                        Text(l10n.statisticsTotalSpend,
                            style: theme.textTheme.labelLarge?.copyWith(color: onHeroMuted)),
                        const SizedBox(height: 4),
                        MoneyText(
                          s.total,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onHero,
                          ),
                          animate: true,
                        ),
                      ],
                    ),
                  ),
                  if (showDelta && s.prevPeriodTotal > 0) _DeltaChip(deltaPct: s.deltaPct, onHero: onHero),
                ],
              ),
              if (showDelta && s.prevPeriodTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.statisticsVsPreviousPeriod,
                    style: theme.textTheme.bodySmall?.copyWith(color: onHeroMuted),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statisticsAvgPerMonth,
                      onHero: onHero,
                      onHeroMuted: onHeroMuted,
                      child: MoneyText(
                        s.avgPerMonth,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onHero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statisticsExpenseCount,
                      onHero: onHero,
                      onHeroMuted: onHeroMuted,
                      child: Text(
                        s.expenseCount.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onHero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statisticsBiggestExpense,
                      onHero: onHero,
                      onHeroMuted: onHeroMuted,
                      child: MoneyText(
                        s.biggestExpense,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onHero,
                        ),
                      ),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.onHero, required this.onHeroMuted, required this.child});
  final String label;
  final Color onHero;
  final Color onHeroMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // v3 wraps each summary stat in a translucent chip tile sitting on the
    // group-tinted hero. The fill derives from the on-hero color (like
    // _DeltaChip) so it stays legible in both light and dark group themes —
    // never a hard-coded prototype hex.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: onHero.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: onHeroMuted)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.deltaPct, required this.onHero});
  final double deltaPct;
  final Color onHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = deltaPct >= 0;
    // On the tinted hero, the chip reads as a translucent on-hero pill so it
    // stays legible in both light and dark group themes.
    final bg = onHero.withValues(alpha: 0.16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 16, color: onHero),
          const SizedBox(width: 4),
          Text(
            '${isUp ? '+' : ''}${deltaPct.toStringAsFixed(1)}%',
            style: theme.textTheme.labelMedium?.copyWith(color: onHero, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
