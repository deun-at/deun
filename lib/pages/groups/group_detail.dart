import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';

import '../../widgets/shimmer_card_list.dart';

class GroupDetail extends StatefulWidget {
  const GroupDetail({super.key, required this.groupDocId});

  final int groupDocId;

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  @override
  void initState() {
    super.initState();
  }

  void updateExpenseList() {
    setState(() {});
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
    Future<Map<String, dynamic>> _groupDetailData = supabase
        .from('group')
        .select('*, expense(*)')
        .eq('id', widget.groupDocId)
        .order('created_at', ascending: false, referencedTable: 'expense')
        .limit(1)
        .single();

    return Scaffold(
        appBar: AppBar(
            leading: const BackButton(),
            title: Text(AppLocalizations.of(context)!.expenses),
            centerTitle: true),
        body: FutureBuilder(
            future: _groupDetailData,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text(AppLocalizations.of(context)!.groupEntriesError,
                        style: Theme.of(context).textTheme.headlineMedium));
              }

              if (!snapshot.hasData) {
                return const ShimmerCardList(
                  height: 120,
                  listEntryLength: 8,
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
                                    .surfaceContainerHighest,
                                surfaceTintColor: colorSeedValue,
                                shadowColor: Colors.transparent,
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(12.0),
                                    onTap: () {
                                      GoRouter.of(context).push(
                                          "/group/details/expense?groupDocId=${widget.groupDocId}&expenseDocId=${expense['id']}");
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
                                                            controller.close();
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
                                                                expense['id']),
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
                                                expense['name'],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium,
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.bottomLeft,
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
            }),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              GoRouter.of(context).push(
                  "/group/details/expense?groupDocId=${widget.groupDocId}");
            },
            label: Text(AppLocalizations.of(context)!.addNewExpense),
            icon: const Icon(Icons.add)));
  }
}
