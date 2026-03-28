import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../expenses/data/expense_model.dart';
import '../../expenses/provider/expense_list.dart';

class GroupDetailList extends ConsumerStatefulWidget {
  const GroupDetailList({super.key, required this.group, this.adBlock});

  final Group group;
  final Widget? adBlock;

  @override
  ConsumerState<GroupDetailList> createState() => _GroupDetailListState();
}

class _GroupDetailListState extends ConsumerState<GroupDetailList> {
  int oldOffset = 0;

  Future<void> updateExpenseList() async {
    return ref.read(expenseListProvider(widget.group.id).notifier).reload(widget.group.id);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    ColorScheme colorScheme = themeData.colorScheme;

    Color cardColor = themeData.brightness == Brightness.light ? colorScheme.primary : colorScheme.primaryContainer;
    Color textColor = themeData.brightness == Brightness.light ? colorScheme.primaryContainer : colorScheme.primary;

    return Consumer(
      builder: (context, ref, child) {
        final expenseListState = ref.watch(expenseListProvider(widget.group.id));
        final isLoading = expenseListState.isLoading;
        final expenses = expenseListState.value;
        oldOffset = ref.read(expenseListProvider(widget.group.id).notifier).offset;

        if (isLoading) {
          return const ShimmerCardList(height: 80, listEntryLength: 15);
        }

        return expenses == null || expenses.isEmpty
            ? EmptyListWidget(
                icon: Icons.receipt_long_outlined,
                label: AppLocalizations.of(context)!.groupExpenseNoEntries,
                onRefresh: () => updateExpenseList(),
              )
            : RefreshIndicator(
                onRefresh: () => updateExpenseList(),
                child: NotificationListener<ScrollNotification>(
                  child: CardListView(
                    color: cardColor,
                    addSpacer: true,
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      if (index == expenses.length) {
                        return const SizedBox(height: 90);
                      }

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
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            child: Text(
                              AppLocalizations.of(context)!.groupDisplayPaidBack(
                                paidByYourself,
                                paidByDisplayName,
                                paidToYourself,
                                paidToDisplayName,
                                expense.amount,
                              ),
                              style: themeData.textTheme.bodyMedium!.copyWith(color: textColor),
                            ),
                          ),
                        );
                      } else {
                        expenseListItem = InkWell(
                          borderRadius: BorderRadius.circular(12.0),
                          onTap: () {
                            GoRouter.of(
                              context,
                            ).push("/group/details/expense", extra: {'group': widget.group, 'expense': expense});
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
                                        style: GoogleFonts.robotoSerif(
                                          textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      formatDate(expense.expenseDate),
                                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: textColor),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ExpenseShareWidget(expense: expense, textColor: textColor),
                                    if (expense.category != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Icon(expense.category!.getIcon(), size: 20, color: textColor),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return expenseListItem;
                    },
                    adBlock: widget.adBlock,
                  ),
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels >
                        scrollInfo.metrics.maxScrollExtent - MediaQuery.of(context).size.height) {
                      if (oldOffset == ref.read(expenseListProvider(widget.group.id).notifier).offset) {
                        // make sure ListView has newest data after previous loadMore
                        ref.read(expenseListProvider(widget.group.id).notifier).loadMoreEntries(widget.group.id);
                      }
                    }
                    return false;
                  },
                ),
              );
      },
    );
  }
}

class ExpenseShareWidget extends StatefulWidget {
  const ExpenseShareWidget({super.key, required this.expense, required this.textColor});

  final Expense expense;
  final Color textColor;

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
      widget.expense.amount,
    );
    Color paidWidgetTextColor = currentUserPaid ? Colors.green : Colors.red;
    if (groupMemberShareStatistic.containsKey(currentUserEmail)) {
      String textLabel = "";
      double? currentUserShares = groupMemberShareStatistic[currentUserEmail];

      if (currentUserPaid) {
        textLabel = AppLocalizations.of(context)!.expenseDisplayAmount(
          'yes',
          AppLocalizations.of(context)!.you,
          "lent",
          widget.expense.amount - (currentUserShares ?? 0),
        );
      } else {
        textLabel = AppLocalizations.of(
          context,
        )!.expenseDisplayAmount('yes', AppLocalizations.of(context)!.you, "borrowed", (currentUserShares ?? 0));
      }
      sharedWidget = Align(
        alignment: Alignment.bottomLeft,
        child: Text(textLabel, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: widget.textColor)),
      );
    } else {
      if (!currentUserPaid) {
        paidWidgetLable = AppLocalizations.of(context)!.expenseNoShares;
        paidWidgetTextColor = widget.textColor;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            paidWidgetLable,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: paidWidgetTextColor),
          ),
        ),
        sharedWidget ?? const SizedBox(),
      ],
    );
  }
}
