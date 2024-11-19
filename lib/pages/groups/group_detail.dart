import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../main.dart';

import '../../constants.dart';
import '../expenses/new_expense.dart';

class GroupDetail extends StatefulWidget {
  const GroupDetail(
      {super.key, required this.handleColorSelect, required this.groupDocId});

  final void Function(int) handleColorSelect;
  final int groupDocId;

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  void updateExpenseList() {
    setState(() {});
  }

  Future<Map<String, dynamic>> fetchDetails() async {
    Map<String, dynamic> data = await supabase
        .from('group')
        .select('*, expense(*)')
        .eq('id', widget.groupDocId)
        .limit(1)
        .single();

    return data;
  }

  void openDeleteItemDialog(BuildContext context, int docId) {
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
            onPressed: () {
              supabase.from('expense').delete().eq('id', docId).then((value) {
                updateExpenseList();
                Navigator.of(context).pop();
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(leading: const BackButton(), centerTitle: true),
        body: Hero(
            tag: widget.groupDocId,
            child: Material(
                child: FutureBuilder(
                    future: fetchDetails(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                AppLocalizations.of(context)!.groupEntriesError,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium));
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            value: null,
                          ),
                        );
                      }

                      // Access the GroupDocumentSnapshot
                      dynamic group = snapshot.data;
                      dynamic expenseList = group['expense'];

                      var colorSeedValue = Color(group['color_value']);

                      return RefreshIndicator(
                          onRefresh: () async {
                            updateExpenseList();
                          },
                          child: ListView.builder(
                              itemCount: expenseList?.length,
                              itemBuilder: (context, index) {
                                // Access the Expense instance
                                dynamic expense = expenseList?[index];

                                var formatAmount =
                                    "€${expense['amount'].toStringAsFixed(2)}";

                                return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Card(
                                        elevation: 8,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainer,
                                        surfaceTintColor: colorSeedValue,
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            onTap: () {
                                              showModalBottomSheet(
                                                  useSafeArea: true,
                                                  context: context,
                                                  showDragHandle: true,
                                                  isScrollControlled: true,
                                                  builder: (context) {
                                                    return ExpenseBottomSheet(
                                                      groupDocId:
                                                          widget.groupDocId,
                                                      expenseDocId:
                                                          expense['id'],
                                                      updateExpenseList:
                                                          updateExpenseList,
                                                    );
                                                  });
                                              // GoRouter.of(context).go(
                                              //     "/group/details/expense?groupDocId=${widget.groupDocId}&expenseDocId=${expense['id']}");
                                            },
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        10, 5, 5, 10),
                                                child: Column(
                                                  children: [
                                                    Align(
                                                        alignment:
                                                            Alignment.topRight,
                                                        child: Directionality(
                                                          textDirection:
                                                              TextDirection.rtl,
                                                          child: MenuAnchor(
                                                            builder: (context,
                                                                controller,
                                                                child) {
                                                              return IconButton(
                                                                icon: const Icon(
                                                                    Icons
                                                                        .more_vert),
                                                                onPressed: () {
                                                                  if (controller
                                                                      .isOpen) {
                                                                    controller
                                                                        .close();
                                                                  } else {
                                                                    controller
                                                                        .open();
                                                                  }
                                                                },
                                                              );
                                                            },
                                                            menuChildren: [
                                                              MenuItemButton(
                                                                closeOnActivate:
                                                                    true,
                                                                onPressed: () =>
                                                                    openDeleteItemDialog(
                                                                        context,
                                                                        expense[
                                                                            'id']),
                                                                trailingIcon:
                                                                    const Icon(Icons
                                                                        .delete),
                                                                child: Text(
                                                                    AppLocalizations.of(
                                                                            context)!
                                                                        .delete),
                                                              ),
                                                            ],
                                                          ),
                                                        )),
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomLeft,
                                                      child: Text(
                                                        expense['name'],
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineMedium,
                                                      ),
                                                    ),
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomLeft,
                                                      child: Text(
                                                        formatAmount,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelLarge,
                                                      ),
                                                    )
                                                  ],
                                                )))));
                              }));
                    }))),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                  useSafeArea: true,
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (context) {
                    return ExpenseBottomSheet(
                      groupDocId: widget.groupDocId,
                      updateExpenseList: updateExpenseList,
                    );
                  });
            },
            label: Text(AppLocalizations.of(context)!.addNewExpense),
            icon: const Icon(Icons.add)));
  }
}
