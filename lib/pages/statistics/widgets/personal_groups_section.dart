import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/personal_statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// By-group breakdown: each group with a tinted color dot, its name, your fair
/// share via [MoneyText], and a [ProgressBar] of its share relative to the
/// largest group. Groups arrive pre-sorted (share desc) from the provider.
class PersonalGroupsSection extends ConsumerWidget {
  const PersonalGroupsSection({super.key, required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalStatisticsProvider(range));
    final l10n = AppLocalizations.of(context)!;

    final groups = state.maybeWhen(
      data: (s) => s.groups,
      orElse: () => const <PersonalGroupSummary>[],
    );
    if (groups.isEmpty) return const SizedBox.shrink();

    final maxShare = maxOfBars([for (final g in groups) g.totalShare]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.statisticsGroupsRanked),
          const SizedBox(height: 8),
          SoftCard(
            child: Column(
              children: [
                for (int i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _GroupRow(group: groups[i], maxShare: maxShare),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.maxShare});

  final PersonalGroupSummary group;
  final double maxShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = Color(group.colorValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.group_outlined, size: 16, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.groupName,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            MoneyText(
              group.totalShare,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(
          value: barFraction(group.totalShare, maxShare),
          fillColor: tint,
        ),
      ],
    );
  }
}
