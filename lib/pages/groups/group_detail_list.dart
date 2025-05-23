import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/expense_entry_model.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../expenses/expense_model.dart';

class GroupDetailList extends ConsumerStatefulWidget {
  const GroupDetailList({super.key, required this.group, this.adBox});

  final Group group;
  final Widget? adBox;

  @override
  ConsumerState<GroupDetailList> createState() => _GroupDetailListState();
}

class _GroupDetailListState extends ConsumerState<GroupDetailList> {
  int oldOffset = 0;

  Future<void> updateExpenseList() async {
    return ref.read(expenseListNotifierProvider(widget.group.id).notifier).reload(widget.group.id);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData cardThemeData = Theme.of(context);
    Color cardColor = cardThemeData.brightness == Brightness.light
        ? cardThemeData.colorScheme.surfaceContainerLowest
        : cardThemeData.colorScheme.surfaceContainerHighest;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Consumer(
        builder: (context, ref, child) {
          final expenseListState = ref.watch(expenseListNotifierProvider(widget.group.id));
          final isLoading = expenseListState.isLoading;
          final expenses = expenseListState.value;
          oldOffset = ref.read(expenseListNotifierProvider(widget.group.id).notifier).offset;

          if (isLoading) {
            return const ShimmerCardList(height: 80, listEntryLength: 8, isNegative: true);
          }

          return expenses!.isEmpty
              ? EmptyListWidget(
                  label: AppLocalizations.of(context)!.groupExpenseNoEntries,
                  onRefresh: () async {
                    await updateExpenseList();
                  })
              : RefreshIndicator(
                  onRefresh: () async {
                    await updateExpenseList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0, left: 8.0),
                    child: NotificationListener<ScrollNotification>(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: expenses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == expenses.length) {
                            return const SizedBox(height: 90);
                          }

                          Widget itemWidget;
                          Expense expense = expenses[index];
                          Widget expenseListItem;

                          if (expense.isPaidBackRow) {
                            String? currentUserEmail = supabase.auth.currentUser?.email;
                            ExpenseEntryShare paidBackEntryShare =
                                expense.expenseEntries.entries.first.value.expenseEntryShares.first;

                            String paidByYourself = expense.paidBy == currentUserEmail ? 'yes' : '';
                            String paidByDisplayName = expense.paidBy == currentUserEmail
                                ? AppLocalizations.of(context)!.you
                                : (expense.paidByDisplayName ?? "");
                            String paidToYourself = paidBackEntryShare.email == currentUserEmail ? 'yes' : '';
                            String paidToDisplayName = paidBackEntryShare.email == currentUserEmail
                                ? AppLocalizations.of(context)!.you
                                : paidBackEntryShare.displayName;

                            expenseListItem = SizedBox(
                              width: double.infinity,
                              child: Card(
                                elevation: 0,
                                color: cardColor,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  child: Text(AppLocalizations.of(context)!.groupDisplayPaidBack(paidByYourself,
                                      paidByDisplayName, paidToYourself, paidToDisplayName, expense.amount)),
                                ),
                              ),
                            );
                          } else {
                            expenseListItem = Card(
                              elevation: 0,
                              color: cardColor,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () {
                                  GoRouter.of(context).push(
                                    "/group/details/expense",
                                    extra: {'group': widget.group, 'expense': expense},
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  child: Column(
                                    children: [
                                      Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Flexible(
                                                child: Text(
                                              expense.name,
                                              style: Theme.of(context).textTheme.headlineMedium,
                                              overflow: TextOverflow.ellipsis,
                                            )),
                                            Text(formatDate(expense.expenseDate),
                                                style: Theme.of(context).textTheme.bodySmall)
                                          ]),
                                      ExpenseShareWidget(expense: expense),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (index == 5 || (expenses.length < 6 && index == expenses.length - 1)) {
                            itemWidget = Column(
                              children: [
                                widget.adBox ?? SizedBox(),
                                expenseListItem,
                              ],
                            );
                          } else {
                            itemWidget = expenseListItem;
                          }

                          return itemWidget;
                        },
                      ),
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels >
                            scrollInfo.metrics.maxScrollExtent - MediaQuery.of(context).size.height) {
                          if (oldOffset == ref.read(expenseListNotifierProvider(widget.group.id).notifier).offset) {
                            // make sure ListView has newest data after previous loadMore
                            ref
                                .read(expenseListNotifierProvider(widget.group.id).notifier)
                                .loadMoreEntries(widget.group.id);
                          }
                        }
                        return false;
                      },
                    ),
                  ),
                );
        },
      ),
    );
  }
}

class ExpenseShareWidget extends StatefulWidget {
  const ExpenseShareWidget({super.key, required this.expense});

  final Expense expense;

  @override
  State<ExpenseShareWidget> createState() => _ExpenseShareWidgetState();
}

class _ExpenseShareWidgetState extends State<ExpenseShareWidget> {
  @override
  Widget build(BuildContext context) {
    String? currentUserEmail = supabase.auth.currentUser?.email;
    bool currentUserPaid = widget.expense.paidBy == currentUserEmail;
    Map<String, double> groupMemberShareStatistic = widget.expense.groupMemberShareStatistic;

    Widget? sharedWidget;
    String paidWidgetLable = AppLocalizations.of(context)!.expenseDisplayAmount(
        currentUserPaid ? 'yes' : '',
        currentUserPaid ? AppLocalizations.of(context)!.you : (widget.expense.paidByDisplayName ?? ""),
        "paid",
        widget.expense.amount);
    Color paidWidgetTextColor = currentUserPaid ? Colors.green : Colors.red;
    if (groupMemberShareStatistic.containsKey(currentUserEmail)) {
      String textLabel = "";
      double? currentUserShares = groupMemberShareStatistic[currentUserEmail];

      if (currentUserPaid) {
        textLabel = AppLocalizations.of(context)!.expenseDisplayAmount(
            'yes', AppLocalizations.of(context)!.you, "lent", widget.expense.amount - (currentUserShares ?? 0));
      } else {
        textLabel = AppLocalizations.of(context)!
            .expenseDisplayAmount('yes', AppLocalizations.of(context)!.you, "borrowed", (currentUserShares ?? 0));
      }
      sharedWidget = Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          textLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      );
    } else {
      if (!currentUserPaid) {
        paidWidgetLable = AppLocalizations.of(context)!.expenseNoShares;
        paidWidgetTextColor = Theme.of(context).colorScheme.onSurface;
      }
    }

    return Column(children: [
      Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          paidWidgetLable,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: paidWidgetTextColor),
        ),
      ),
      sharedWidget ?? const SizedBox(),
    ]);
  }
}
