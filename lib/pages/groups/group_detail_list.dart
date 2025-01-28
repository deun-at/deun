import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../expenses/expense_model.dart';

class GroupDetailList extends ConsumerStatefulWidget {
  const GroupDetailList({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupDetailList> createState() => _GroupDetailListState();
}

class _GroupDetailListState extends ConsumerState<GroupDetailList> {
  Future<void> updateExpenseList() async {
    return ref.read(groupDetailNotifierProvider(widget.group.id).notifier).reload(widget.group.id);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Group> groupDetail = ref.watch(groupDetailNotifierProvider(widget.group.id));

    return switch (groupDetail) {
      AsyncData(:final value) => value.expenses!.isEmpty
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
                  child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: value.expenses!.length,
                      itemBuilder: (context, index) {
                        Expense expense = value.expenses![index];

                        if (expense.isPaidBackRow) {
                          return Card(
                              elevation: 8,
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              shadowColor: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                child: Text(AppLocalizations.of(context)!
                                    .groupDisplayPaidBack(expense.paidByDisplayName ?? '', '', expense.amount)),
                              ));
                        }

                        return Card(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            shadowColor: Colors.transparent,
                            child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () {
                                  GoRouter.of(context)
                                      .push("/group/details/expense", extra: {'group': value, 'expense': expense});
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
                                    ))));
                      }))),
      AsyncError() => EmptyListWidget(
          label: AppLocalizations.of(context)!.groupNoEntries,
          onRefresh: () async {
            await updateExpenseList();
          }),
      _ => const ShimmerCardList(
          height: 120,
          listEntryLength: 8,
        ),
    };
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
        currentUserPaid ? AppLocalizations.of(context)!.you : (widget.expense.paidByDisplayName ?? ""),
        "paid",
        widget.expense.amount);
    Color paidWidgetTextColor = currentUserPaid ? Colors.green : Colors.red;
    if (groupMemberShareStatistic.containsKey(currentUserEmail)) {
      String textLabel = "";
      double? currentUserShares = groupMemberShareStatistic[currentUserEmail];

      if (currentUserPaid) {
        textLabel = AppLocalizations.of(context)!.expenseDisplayAmount(
            AppLocalizations.of(context)!.you, "lent", widget.expense.amount - (currentUserShares ?? 0));
      } else {
        textLabel = AppLocalizations.of(context)!
            .expenseDisplayAmount(AppLocalizations.of(context)!.you, "borrowed", (currentUserShares ?? 0));
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
