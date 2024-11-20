import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:split_it_supa/main.dart';

import '../../widgets/shimmer_card_list.dart';
import 'new_group.dart';

class GroupList extends StatefulWidget {
  const GroupList({super.key});

  @override
  State<GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<GroupList> {
  @override
  void initState() {
    super.initState();
  }

  void updateGroupList() {
    setState(() {});
  }

  void openDeleteItemDialog(BuildContext context, int groupId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.groupDeleteItemTitle),
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
              supabase.from('group').delete().eq('id', groupId).then((value) {
                updateGroupList();
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
    Future<List<Map<String, dynamic>>> _groupListData = supabase.from('group').select(
        '*, expense(expense_amount:amount.sum(), expense_newest_edit:created_at.max())');

    return Scaffold(
        body: FutureBuilder(
            future: _groupListData,
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

              // Access the QuerySnapshot
              return RefreshIndicator(
                  onRefresh: () async {
                    updateGroupList();
                  },
                  child: ListView.builder(
                    itemCount: snapshot.data?.length,
                    itemBuilder: (context, index) {
                      // Access the Group instance
                      dynamic group = snapshot.data?[index];

                      Color colorSeedValue = Color(group['color_value']);

                      dynamic expenseAmount =
                          group['expense'].first['expense_amount'] ?? 0;
                      double sumAmount = double.parse(expenseAmount.toString());
                      String formatSumAmount =
                          "€${sumAmount.toStringAsFixed(2)}";

                      return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Card(
                              elevation: 8,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              surfaceTintColor: colorSeedValue,
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(12.0),
                                  onTap: () {
                                    GoRouter.of(context).push(
                                        "/group/details?groupDocId=${group["id"]}");
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
                                                  builder: (context, controller,
                                                      child) {
                                                    return IconButton(
                                                      icon: const Icon(
                                                          Icons.more_vert),
                                                      onPressed: () {
                                                        if (controller.isOpen) {
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
                                                              group['id']),
                                                      trailingIcon: const Icon(
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
                                              group['name'],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Text(
                                              formatSumAmount,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                            ),
                                          )
                                        ],
                                      )))));
                    },
                  ));
            }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
                useSafeArea: true,
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) {
                  return NewGroup(updateGroupList: updateGroupList);
                });
          },
          label: Text(AppLocalizations.of(context)!.addNewGroup),
          icon: const Icon(Icons.add),
        ));
  }
}
