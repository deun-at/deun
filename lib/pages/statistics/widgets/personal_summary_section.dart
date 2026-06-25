import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal "your spending" hero: a dark ink card (lighter raised card in dark
/// mode) showing your total fair share (large) with paid / expense-count mini
/// stats below.
///
/// Mirrors the overall-balance dark hero on the group list (DESIGN_SPEC "Dark
/// hero card": #16181A light / #262824 dark) so the two read as one family.
class PersonalSummarySection extends ConsumerWidget {
  const PersonalSummarySection({super.key, required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalStatisticsProvider(range));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color heroSurface = isDark ? colorScheme.surfaceBright : colorScheme.onSurface;
    final Color onHero = isDark ? colorScheme.onSurface : colorScheme.surface;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: heroSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? null : kDarkHeroShadow,
        ),
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
              Text(
                l10n.statisticsTotalSpend,
                style: theme.textTheme.labelLarge?.copyWith(color: onHeroMuted),
              ),
              const SizedBox(height: 6),
              MoneyText(
                s.totalShare,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onHero,
                ),
                animate: true,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statisticsMemberPaid,
                      onHeroMuted: onHeroMuted,
                      child: MoneyText(
                        s.totalPaid,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onHero,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.statisticsExpenseCount,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled mini stat inside the personal hero.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.onHeroMuted, required this.child});

  final String label;
  final Color onHeroMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: onHeroMuted)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
