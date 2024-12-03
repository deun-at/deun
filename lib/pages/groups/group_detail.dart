import 'package:deun/main.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../app_state.dart';

import '../../helper/helper.dart';
import '../expenses/expense_model.dart';
import 'group_model.dart';

class GroupDetail extends StatefulWidget {
  const GroupDetail({super.key, required this.appState, required this.groupId});

  final AppState appState;
  final String groupId;

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> updateExpenseList() async {
    // Notify the ListPage to reload
    await widget.appState.fetchGroupData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Group? group = widget.appState.groupItems.value.data[widget.groupId];

    if (group == null) {
      return Container();
    }

    // Access the GroupDocumentSnapshot
    var colorSeedValue = Color(group.colorValue);
    Map<String, Expense> expenses = group.expenses;

    return Scaffold(
        appBar: AppBar(leading: const BackButton(), title: Text(group.name), centerTitle: true),
        body: Hero(
            tag: "group_card_${group.id}",
            child: Material(
                color: Colors.transparent,
                child: RefreshIndicator(
                    onRefresh: () async {
                      await updateExpenseList();
                    },
                    child: group.expenses.isEmpty
                        ? EmptyListWidget(
                            label: AppLocalizations.of(context)!.groupExpenseNoEntries,
                            onRefresh: () async {
                              await updateExpenseList();
                            })
                        : ListView.builder(
                            itemCount: group.expenses.length,
                            itemBuilder: (context, index) {
                              String expenseId = expenses.keys.elementAt(index);
                              // Access the Group instance
                              Expense? expense = expenses[expenseId];

                              if (expense == null) {
                                return Container();
                              }

                              return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Card(
                                      elevation: 8,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      surfaceTintColor: colorSeedValue,
                                      shadowColor: Colors.transparent,
                                      child: InkWell(
                                          borderRadius: BorderRadius.circular(12.0),
                                          onTap: () {
                                            GoRouter.of(context).push("/group/details/expense?groupId=${widget.groupId}&expenseId=${expense.id}");
                                          },
                                          child: Padding(
                                              padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                              child: Column(
                                                children: [
                                                  Align(
                                                    alignment: Alignment.bottomLeft,
                                                    child: Text(
                                                      expense.name,
                                                      style: Theme.of(context).textTheme.headlineMedium,
                                                    ),
                                                  ),
                                                  ExpenseShareWidget(expense: expense),
                                                ],
                                              )))));
                            })))),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              GoRouter.of(context).push("/group/details/expense?groupId=${group.id}");
            },
            label: Text(AppLocalizations.of(context)!.addNewExpense),
            icon: const Icon(Icons.add)));
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
    String paidWidgetLable = AppLocalizations.of(context)!
        .expenseDisplayAmount(currentUserPaid ? AppLocalizations.of(context)!.you : (widget.expense.paidByDisplayName ?? ""), "paid", widget.expense.amount);
    if (groupMemberShareStatistic.containsKey(currentUserEmail)) {
      String textLabel = "";
      double? currentUserShares = groupMemberShareStatistic[currentUserEmail];
      if (currentUserPaid) {
        textLabel = AppLocalizations.of(context)!.expenseDisplayAmount(AppLocalizations.of(context)!.you, "lent", widget.expense.amount - (currentUserShares ?? 0));
      } else {
        textLabel = AppLocalizations.of(context)!.expenseDisplayAmount(AppLocalizations.of(context)!.you, "borrowed", (currentUserShares ?? 0));
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
      }
    }

    return Column(children: [
      Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          paidWidgetLable,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      sharedWidget ?? const SizedBox(),
    ]);
  }
}
