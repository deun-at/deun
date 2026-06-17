import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/pages/statistics/widgets/stats_chart_math.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Restyled month detail sheet: per-member spend for a single month, in a
/// [SheetScaffold] with restyle list rows.
class StatisticsMonthDetailBottomSheet extends ConsumerWidget {
  const StatisticsMonthDetailBottomSheet({
    super.key,
    required this.group,
    required this.monthStart,
    required this.monthEnd,
  });

  final Group group;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = GroupMonthMemberTotalsArgs(groupId: group.id, monthStart: monthStart, monthEnd: monthEnd);
    final state = ref.watch(groupMonthMemberTotalsProvider(args));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SheetScaffold(
      title: DateFormat('MMMM yyyy').format(monthStart),
      titleTrailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          state.when(
            loading: () => const ShimmerCardList(height: 60, listEntryLength: 4),
            error: (error, _) => _Empty(text: l10n.statisticsNoExpensesFound, theme: theme),
            data: (members) {
              final filtered = members.where((m) => m.total > 0).toList();
              if (filtered.isEmpty) {
                return _Empty(text: l10n.statisticsNoExpensesFound, theme: theme);
              }
              final total = filtered.fold<double>(0, (a, m) => a + m.total);
              return SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final item in filtered)
                      ListTile(
                        leading: MemberAvatar(name: item.displayName, colorKey: item.email),
                        title: Text(item.displayName, style: theme.textTheme.bodyLarge),
                        subtitle: Text('${percentOfTotal(item.total, total).toStringAsFixed(1)}%'),
                        trailing: MoneyText(
                          item.total,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
