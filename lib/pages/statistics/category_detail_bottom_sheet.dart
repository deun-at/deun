import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/expense_category.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:deun/l10n/app_localizations.dart';

class CategoryDetailBottomSheet extends ConsumerWidget {
  const CategoryDetailBottomSheet({
    super.key,
    required this.groupId,
    required this.categoryName,
    required this.monthStart,
    required this.monthEnd,
  });

  final String groupId;
  final String categoryName;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = CategoryExpenseDetailsArgs(
      groupId: groupId,
      categoryName: categoryName,
      monthStart: monthStart,
      monthEnd: monthEnd,
    );
    final state = ref.watch(categoryExpenseDetailsNotifierProvider(args));
    final localizations = AppLocalizations.of(context)!;

    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => ExpenseCategory.other,
    );

    return DraggableScrollableSheet(
      expand: true,
      initialChildSize: .8,
      snap: true,
      builder: (context, scrollController) {
        return RoundedContainer(
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(
                    category.getIcon(),
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.getDisplayName(localizations),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          DateFormat("MMMM yyyy").format(monthStart),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              centerTitle: true,
            ),
            body: Container(
              color: Theme.of(context).colorScheme.surface,
              child: state.when(
                loading: () => const Center(
                  child: ShimmerCardList(
                    height: 60,
                    listEntryLength: 8,
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $error',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No expenses found'),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final date = DateTime.parse(expense.expenseDate);

                      return ListTile(
                        title: Text(
                          expense.expenseName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat("MMM d, yyyy").format(date),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              'Paid by ${expense.paidByDisplayName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          toCurrency(expense.amount),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
