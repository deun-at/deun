import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final canPage = current != StatsRange.allTime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          SegmentedButton<StatsRange>(
            style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: StatsRange.threeMonths, label: Text(l10n.statisticsRangeThreeMonths)),
              ButtonSegment(value: StatsRange.sixMonths, label: Text(l10n.statisticsRangeSixMonths)),
              ButtonSegment(value: StatsRange.twelveMonths, label: Text(l10n.statisticsRangeTwelveMonths)),
              ButtonSegment(value: StatsRange.allTime, label: Text(l10n.statisticsRangeAllTime)),
            ],
            selected: {current},
            onSelectionChanged: (set) => onChanged(set.first),
          ),
          if (canPage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Older',
                    onPressed: () => onOffsetChanged(offsetMonths + 1),
                  ),
                  Text(
                    _windowLabel(current, offsetMonths),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Newer',
                    onPressed: offsetMonths > 0 ? () => onOffsetChanged(offsetMonths - 1) : null,
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
