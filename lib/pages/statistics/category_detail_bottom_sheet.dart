import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/expense_category.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/rounded_container.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:deun/widgets/sliver_grab_widget.dart';
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
    final state = ref.watch(categoryExpenseDetailsProvider(args));
    final localizations = AppLocalizations.of(context)!;

    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => ExpenseCategory.other,
    );

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
                      Icon(
                        category.getIcon(),
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
                ),
                state.when(
                  loading: () => SliverToBoxAdapter(
                    child: ShimmerCardList(
                      height: 60,
                      listEntryLength: 8,
                    ),
                  ),
                  error: (error, stackTrace) => SliverToBoxAdapter(
                      child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: $error',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  )),
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return SliverToBoxAdapter(
                          child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(localizations.statisticsNoExpensesFound),
                        ),
                      ));
                    }

                    return SliverList.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final date = DateTime.parse(expense.expenseDate);

                        bool isTop = false;
                        bool isBottom = false;

                        if (index == 0) {
                          isTop = true;
                        }

                        if (index == expenses.length - 1) {
                          isBottom = true;
                        }

                        return CardListTile(
                          isTop: isTop,
                          isBottom: isBottom,
                          child: ListTile(
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  localizations.paidBy(expense.paidByDisplayName),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
}
