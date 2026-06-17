import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-member paid-vs-fair-share bars with a signed balance amount per member.
class StatsMembersSection extends ConsumerWidget {
  const StatsMembersSection({super.key, required this.args});
  final StatsRangeArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupMemberBreakdownProvider(args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.statisticsMembers),
          const SizedBox(height: 8),
          SoftCard(
            child: state.when(
              loading: () => const ShimmerCardList(height: 56, listEntryLength: 3),
              error: (e, _) => Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium),
              data: (members) {
                if (members.isEmpty) {
                  return Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium);
                }
                final maxVal = maxOfBars([
                  for (final m in members) ...[m.paid, m.fairShare],
                ]);
                return Column(
                  children: [
                    for (int i = 0; i < members.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                        child: _MemberRow(member: members[i], maxVal: maxVal),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.maxVal});
  final MemberSpendingBreakdown member;
  final double maxVal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final delta = member.delta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MemberAvatar(name: member.displayName, colorKey: member.email, radius: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                member.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            MoneyText(
              delta,
              semantic: MoneySemantic.auto,
              showSign: true,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MemberBar(
          label: l10n.statisticsMemberPaid,
          value: member.paid,
          fraction: barFraction(member.paid, maxVal),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 6),
        _MemberBar(
          label: l10n.statisticsMemberFairShare,
          value: member.fairShare,
          fraction: barFraction(member.fairShare, maxVal),
          color: theme.colorScheme.tertiary,
        ),
      ],
    );
  }
}

class _MemberBar extends StatelessWidget {
  const _MemberBar({required this.label, required this.value, required this.fraction, required this.color});
  final String label;
  final double value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: ProgressBar(value: fraction, fillColor: color)),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: MoneyText(
            value,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
