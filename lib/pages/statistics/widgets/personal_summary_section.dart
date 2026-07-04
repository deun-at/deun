import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal "your spending" hero: a dark ink card (lighter raised card in dark
/// mode) leading with an "Across all groups" + period eyebrow, then a dual
/// "You paid €X" / "Your share €Y" layout with the share tinted accent (v3
/// mockup L669-681, design_14).
///
/// Mirrors the overall-balance dark hero on the group list (DESIGN_SPEC "Dark
/// hero card": #16181A light / #262824 dark) so the two read as one family.
class PersonalSummarySection extends ConsumerWidget {
  const PersonalSummarySection({super.key, required this.range});

  final StatsRange range;

  /// Eyebrow period label reflecting the ACTUAL window the data covers, driven
  /// by [range] (not a hard-coded "6 months").
  String _period(AppLocalizations l10n) => range == StatsRange.allTime
      ? l10n.statisticsPeriodAllTime
      : l10n.statisticsPeriodLastMonths(range.months!);

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
    // Share accent (mockup #C7B6F0): a light lavender that reads on the ink
    // card. inversePrimary is the primary tint designed for inverse (dark)
    // surfaces in the light theme; on the light-raised dark-theme card, primary
    // is the readable accent.
    final Color shareAccent = isDark ? colorScheme.primary : colorScheme.inversePrimary;

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
                '${l10n.statisticsAcrossAllGroups} · ${_period(l10n)}',
                style: theme.textTheme.labelMedium?.copyWith(color: onHeroMuted),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HeroAmount(
                      label: l10n.statisticsYouPaid,
                      onHeroMuted: onHeroMuted,
                      child: MoneyText(
                        s.totalPaid,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onHero,
                        ),
                        animate: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _HeroAmount(
                      label: l10n.statisticsYourShare,
                      onHeroMuted: onHeroMuted,
                      child: MoneyText(
                        s.totalShare,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: shareAccent,
                        ),
                        animate: true,
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

/// One labelled amount inside the personal hero (label above, amount below).
class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.label, required this.onHeroMuted, required this.child});

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
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
