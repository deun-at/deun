import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatisticsMonthDetailBottomSheet extends ConsumerWidget {
  const StatisticsMonthDetailBottomSheet(
      {super.key, required this.group, required this.monthStart, required this.monthEnd});

  final Group group;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = GroupMonthMemberTotalsArgs(groupId: group.id, monthStart: monthStart, monthEnd: monthEnd);
    final state = ref.watch(groupMonthMemberTotalsNotifierProvider(args));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Details ${monthStart.month.toString().padLeft(2, '0')}/${monthStart.year}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text(e.toString()),
              data: (list) {
                if (list.isEmpty) {
                  return const Text('No expenses');
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      return ListTile(
                        title: Text(item.displayName),
                        trailing: Text(toCurrency(item.total)),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
