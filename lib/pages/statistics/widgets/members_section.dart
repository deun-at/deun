import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsMembersSection extends ConsumerWidget {
  const StatsMembersSection({super.key, required this.args});
  final StatsRangeArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupMemberBreakdownProvider(args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statisticsMembers, style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              state.when(
                loading: () => const ShimmerCardList(height: 56, listEntryLength: 3),
                error: (e, _) => Text(e.toString()),
                data: (members) {
                  if (members.isEmpty) {
                    return Text(l10n.statisticsNoExpenses, style: theme.textTheme.bodyMedium);
                  }
                  final maxVal = members
                      .fold<double>(0, (a, m) => [m.paid, m.fairShare, a].reduce((x, y) => x > y ? x : y));
                  return Column(
                    children: [
                      for (final m in members)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _MemberRow(member: m, maxVal: maxVal),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
    final paidPct = maxVal > 0 ? (member.paid / maxVal).clamp(0.0, 1.0) : 0.0;
    final sharePct = maxVal > 0 ? (member.fairShare / maxVal).clamp(0.0, 1.0) : 0.0;
    final delta = member.delta;
    final deltaColor = delta >= 0 ? Colors.green.shade700 : theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                _initials(member.displayName),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                member.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(delta >= 0 ? '+' : '')}${toCurrency(delta)}',
              style: theme.textTheme.labelMedium?.copyWith(color: deltaColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _MemberBar(
          label: l10n.statisticsMemberPaid,
          value: member.paid,
          fraction: paidPct,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        _MemberBar(
          label: l10n.statisticsMemberFairShare,
          value: member.fairShare,
          fraction: sharePct,
          color: theme.colorScheme.tertiary,
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
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
        SizedBox(width: 80, child: Text(label, style: theme.textTheme.labelSmall)),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(toCurrency(value), style: theme.textTheme.labelMedium, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
