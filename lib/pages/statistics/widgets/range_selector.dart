import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Range control: a 3M / 6M / 12M / All segmented control plus a period stepper
/// that walks the window into the past (for bounded ranges only).
class StatsRangeSelector extends StatelessWidget {
  const StatsRangeSelector({
    super.key,
    required this.current,
    required this.onChanged,
    required this.offsetMonths,
    required this.onOffsetChanged,
  });

  final StatsRange current;
  final ValueChanged<StatsRange> onChanged;
  final int offsetMonths;
  final ValueChanged<int> onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canPage = current != StatsRange.allTime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          AppSegmentedControl<StatsRange>(
            value: current,
            onChanged: onChanged,
            segments: [
              AppSegment(value: StatsRange.threeMonths, label: l10n.statisticsRangeThreeMonths),
              AppSegment(value: StatsRange.sixMonths, label: l10n.statisticsRangeSixMonths),
              AppSegment(value: StatsRange.twelveMonths, label: l10n.statisticsRangeTwelveMonths),
              AppSegment(value: StatsRange.allTime, label: l10n.statisticsRangeAllTime),
            ],
          ),
          if (canPage)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _Stepper(
                      label: _windowLabel(current, offsetMonths),
                      // Minus walks into the past (older), plus walks toward now.
                      onOlder: () => onOffsetChanged(offsetMonths + 1),
                      onNewer: offsetMonths > 0 ? () => onOffsetChanged(offsetMonths - 1) : null,
                      labelStyle:
                          theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _windowLabel(StatsRange range, int offset) {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - offset, 1);
    if (range == StatsRange.allTime) return '';
    final months = range.months!;
    if (months == 1) return DateFormat('MMM yyyy').format(last);
    final first = DateTime(last.year, last.month - (months - 1), 1);
    if (first.year == last.year) {
      return '${DateFormat('MMM').format(first)} – ${DateFormat('MMM yyyy').format(last)}';
    }
    return '${DateFormat('MMM yyyy').format(first)} – ${DateFormat('MMM yyyy').format(last)}';
  }
}

/// A period stepper pill mirroring [StepperControl]'s look but sized to hold a
/// wider date-range [label] between the two arrows. [onNewer] is null at the
/// present period (so the newer arrow disables).
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.onOlder,
    required this.onNewer,
    required this.labelStyle,
  });

  final String label;
  final VoidCallback onOlder;
  final VoidCallback? onNewer;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(icon: Icons.chevron_left, onTap: onOlder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(label, style: labelStyle, textAlign: TextAlign.center),
          ),
          _Arrow(icon: Icons.chevron_right, onTap: onNewer),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final color = enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
