import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:deun/widgets/sliver_grab_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (context, scrollController) {
          return RoundedContainer(
            child: Scaffold(
              body: CustomScrollView(controller: scrollController, slivers: [
                const SliverGrabWidget(),
                SliverAppBar(
                  pinned: true,
                  title: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(monthStart),
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              group.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                state.when(
                  loading: () => const SliverToBoxAdapter(
                    child: ShimmerCardList(height: 60, listEntryLength: 4),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error: $error',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                  data: (members) {
                    final filtered = members.where((m) => m.total > 0).toList();
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(localizations.statisticsNoExpensesFound),
                          ),
                        ),
                      );
                    }
                    final total = filtered.fold<double>(0, (a, m) => a + m.total);
                    return SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final pct = total > 0 ? (item.total / total * 100) : 0.0;
                        return CardListTile(
                          isTop: index == 0,
                          isBottom: index == filtered.length - 1,
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                _initials(item.displayName),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              item.displayName,
                              style: theme.textTheme.bodyLarge,
                            ),
                            subtitle: Text('${pct.toStringAsFixed(1)}%'),
                            trailing: Text(
                              toCurrency(item.total),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
