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

  void openDeleteItemDialog(BuildContext context, Expense expense) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.expenseDeleteItemTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () async {
              await expense.delete();
              await updateExpenseList();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Group? group = widget.appState.groupItems.value[widget.groupId];

    if (group == null) {
      return Container();
    }

    // Access the GroupDocumentSnapshot
    var colorSeedValue = Color(group.colorValue);
    Map<String, Expense> expenses = group.expenses;

    return Scaffold(
        appBar: AppBar(
            leading: const BackButton(),
            title: Text(group.name),
            centerTitle: true),
        body: Hero(
            tag: "group_card_${group.id}",
            child: Material(
                color: Colors.transparent,
                child: RefreshIndicator(
                    onRefresh: () async {
                      await updateExpenseList();
                    },
                    child: ListView.builder(
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  surfaceTintColor: colorSeedValue,
                                  shadowColor: Colors.transparent,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(12.0),
                                      onTap: () {
                                        GoRouter.of(context).push(
                                            "/group/details/expense?groupId=${widget.groupId}&expenseId=${expense.id}");
                                      },
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 5, 5, 10),
                                          child: Column(
                                            children: [
                                              Align(
                                                  alignment: Alignment.topRight,
                                                  child: Directionality(
                                                    textDirection:
                                                        TextDirection.rtl,
                                                    child: MenuAnchor(
                                                      builder: (context,
                                                          controller, child) {
                                                        return IconButton(
                                                          icon: const Icon(
                                                              Icons.more_vert),
                                                          onPressed: () {
                                                            if (controller
                                                                .isOpen) {
                                                              controller
                                                                  .close();
                                                            } else {
                                                              controller.open();
                                                            }
                                                          },
                                                        );
                                                      },
                                                      menuChildren: [
                                                        MenuItemButton(
                                                          closeOnActivate: true,
                                                          onPressed: () =>
                                                              openDeleteItemDialog(
                                                                  context,
                                                                  expense),
                                                          trailingIcon:
                                                              const Icon(
                                                                  Icons.delete),
                                                          child: Text(
                                                              AppLocalizations.of(
                                                                      context)!
                                                                  .delete),
                                                        ),
                                                      ],
                                                    ),
                                                  )),
                                              Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  expense.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium,
                                                ),
                                              ),
                                              Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  toCurrency(expense.amount),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                              )
                                            ],
                                          )))));
                        })))),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              GoRouter.of(context)
                  .push("/group/details/expense?groupId=${group.id}");
            },
            label: Text(AppLocalizations.of(context)!.addNewExpense),
            icon: const Icon(Icons.add)));
  }
}
