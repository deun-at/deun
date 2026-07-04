import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Monthly trend: always themed bars, with only the latest month tinted the
/// group color and the rest neutral. Tapping a month opens the month detail
/// sheet via [onMonthTap].
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.statisticsTrend),
          const SizedBox(height: 8),
          SoftCard(
            child: SizedBox(
              height: 180,
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium)),
                data: (months) {
                  if (months.isEmpty) {
                    return Center(
                      child: Text(l10n.statisticsNoExpenses,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    );
                  }
                  return _TrendBars(months: months, onMonthTap: onMonthTap);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBars extends StatefulWidget {
  const _TrendBars({required this.months, required this.onMonthTap});
  final List<MonthBucket> months;
  final ValueChanged<MonthBucket> onMonthTap;

  @override
  State<_TrendBars> createState() => _TrendBarsState();
}

class _TrendBarsState extends State<_TrendBars> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Motion.barGrowDuration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Motion.barGrow);

    // Start grow on next frame so the widget has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        // Skip to end immediately.
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = widget.months;

    if (months.isEmpty) return const SizedBox.shrink();

    final maxTotal = months.map((m) => m.total).reduce((a, b) => a > b ? a : b);
    final step = labelStep(months.length);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < months.length; i++)
              // Only the latest (last) month is tinted the group color; every
              // other bar uses a neutral track token (F64 / v3 monthly-trend).
              Builder(builder: (context) {
                final isLatest = i == months.length - 1;
                final barColor = isLatest
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest;
                final labelColor = isLatest
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onMonthTap(months[i]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Animated bar fill growing from bottom.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: _animation.value,
                              child: FractionallySizedBox(
                                heightFactor: maxTotal > 0 ? months[i].total / maxTotal : 0,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Month label (shown for every nth bar).
                        SizedBox(
                          height: 26,
                          child: (i % step == 0 || i == months.length - 1)
                              ? Text(
                                  DateFormat('MMM yy').format(months[i].start),
                                  style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
