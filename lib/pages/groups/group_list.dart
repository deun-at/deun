import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../helper/helper.dart';
import '../../widgets/shimmer_card_list.dart';
import 'group_model.dart';

class GroupList extends StatefulWidget {
  const GroupList({super.key, required this.appState});

  final AppState appState;

  @override
  State<GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<GroupList> {
  @override
  void initState() {
    super.initState();
    updateGroupList();
  }

  Future<void> updateGroupList() async {
    // Notify the ListPage to reload
    await widget.appState.fetchGroupData();
  }

  void openDeleteItemDialog(BuildContext context, Group group) {
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
            onPressed: () async {
              await group.delete();
              await updateGroupList();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.groups),
          centerTitle: true,
        ),
        body: ValueListenableBuilder<Map<String, Group>>(
            valueListenable: widget.appState.groupItems,
            builder: (context, items, _) {
              if (items.isEmpty) {
                return const ShimmerCardList(
                  height: 120,
                  listEntryLength: 8,
                );
              }

              // Access the QuerySnapshot
              return RefreshIndicator(
                  onRefresh: () async {
                    await updateGroupList();
                  },
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      String groupId = items.keys.elementAt(index);
                      // Access the Group instance
                      Group? group = items[groupId];

                      if (group == null) {
                        return Container();
                      }

                      Color colorSeedValue = Color(group.colorValue);

                      return Hero(
                          tag: "group_card_${group.id}",
                          child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Card(
                                  elevation: 5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  surfaceTintColor: colorSeedValue,
                                  shadowColor: Colors.transparent,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(12.0),
                                      onTap: () {
                                        GoRouter.of(context).push(
                                            "/group/details?groupId=${group.id}");
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
                                                          onPressed: () {
                                                            GoRouter.of(context)
                                                                .push(
                                                                    "/group/edit?groupId=${group.id}");
                                                          },
                                                          trailingIcon:
                                                              const Icon(
                                                                  Icons.edit),
                                                          child: Text(
                                                              AppLocalizations.of(
                                                                      context)!
                                                                  .edit),
                                                        ),
                                                        MenuItemButton(
                                                          closeOnActivate: true,
                                                          onPressed: () =>
                                                              openDeleteItemDialog(
                                                                  context,
                                                                  group),
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
                                                  group.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium,
                                                ),
                                              ),
                                              Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  toCurrency(group.sumAmount),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                              )
                                            ],
                                          ))))));
                    },
                  ));
            }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            GoRouter.of(context).push("/group/edit");
          },
          label: Text(AppLocalizations.of(context)!.addNewGroup),
          icon: const Icon(Icons.add),
        ));
  }
}
