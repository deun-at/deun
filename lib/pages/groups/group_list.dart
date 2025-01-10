import 'package:deun/main.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../provider.dart';
import '../../widgets/shimmer_card_list.dart';
import 'group_model.dart';

class GroupList extends ConsumerStatefulWidget {
  const GroupList({super.key});

  @override
  ConsumerState<GroupList> createState() => _GroupListState();
}

class _GroupListState extends ConsumerState<GroupList> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> updateGroupList() async {
    return ref.refresh(groupListProvider.future);
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
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Group>> groupList = ref.watch(groupListProvider);

    supabase
        .channel('public:group_update_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) {
              debugPrint("group update checker changed");
              updateGroupList();
            })
        .subscribe();

    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.expenses),
          centerTitle: true,
        ),
        body: Container(
            color: Theme.of(context).colorScheme.surface,
            child: switch (groupList) {
              AsyncData(:final value) => value.isEmpty
                  ? EmptyListWidget(
                      label: AppLocalizations.of(context)!.groupNoEntries,
                      onRefresh: () async {
                        await updateGroupList();
                      })
                  : RefreshIndicator(
                      onRefresh: () async {
                        await updateGroupList();
                      },
                      child: Padding(
                          padding: const EdgeInsets.only(right: 8.0, left: 8.0),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: value.length,
                            itemBuilder: (context, index) {
                              // Access the Group instance
                              Group group = value[index];
                              Color colorSeedValue = Color(group.colorValue);

                              return Card(
                                  elevation: 14,
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  surfaceTintColor: colorSeedValue,
                                  shadowColor: Colors.transparent,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(12.0),
                                      onTap: () {
                                        ref.read(themeColorProvider.notifier).setColor(Color(group.colorValue));
                                        GoRouter.of(context).push("/group/details", extra: group).then(
                                          (value) async {
                                            ref.read(themeColorProvider.notifier).resetColor();
                                            await updateGroupList();
                                          },
                                        );
                                      },
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Flexible(
                                                      child: Text(
                                                    group.name,
                                                    style: Theme.of(context).textTheme.headlineMedium,
                                                    overflow: TextOverflow.ellipsis,
                                                  )),
                                                  Directionality(
                                                    textDirection: TextDirection.rtl,
                                                    child: MenuAnchor(
                                                      builder: (context, controller, child) {
                                                        return IconButton(
                                                          icon: const Icon(Icons.more_vert),
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
                                                          onPressed: () {
                                                            GoRouter.of(context).push("/group/edit", extra: group);
                                                          },
                                                          trailingIcon: const Icon(Icons.edit),
                                                          child: Text(AppLocalizations.of(context)!.edit),
                                                        ),
                                                        MenuItemButton(
                                                          closeOnActivate: true,
                                                          onPressed: () => openDeleteItemDialog(context, group),
                                                          trailingIcon: const Icon(Icons.delete),
                                                          child: Text(AppLocalizations.of(context)!.delete),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              GroupShareWidget(group: group),
                                            ],
                                          ))));
                            },
                          ))),
              AsyncError() => EmptyListWidget(
                  label: AppLocalizations.of(context)!.groupNoEntries,
                  onRefresh: () async {
                    await updateGroupList();
                  }),
              _ => const ShimmerCardList(
                  height: 100,
                  listEntryLength: 8,
                ),
            }),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: "floating_action_button_main",
          onPressed: () {
            GoRouter.of(context).push("/group/edit");
          },
          label: Text(AppLocalizations.of(context)!.addNewGroup),
          icon: const Icon(Icons.add),
        ));
  }
}

class GroupShareWidget extends StatelessWidget {
  const GroupShareWidget({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    double totalSharedSum = 0;

    List<Widget> sharedWidget = group.groupSharesSummary
        .map(
          (String key, GroupSharesSummary e) {
            if (e.shareAmount == 0) {
              return MapEntry(key, const SizedBox());
            }

            totalSharedSum += e.shareAmount;
            Color textColor = Colors.red;
            String paidByYourself = "";
            if (e.shareAmount > 0) {
              paidByYourself = "yes";
              textColor = Colors.green;
            }
            textColor = Theme.of(context).colorScheme.onSurface;

            return MapEntry(
                key,
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    AppLocalizations.of(context)!
                        .groupDisplayAmount(e.dipslayName, paidByYourself, e.shareAmount.abs()),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                  ),
                ));
          },
        )
        .entries
        .map((e) => e.value)
        .toList();

    String paidByYourselfAll = "";
    Color textColorAll = Colors.red;
    if (totalSharedSum > 0) {
      paidByYourselfAll = "yes";
      textColorAll = Colors.green;
    }

    String totalSharedText =
        AppLocalizations.of(context)!.groupDisplaySumAmount(paidByYourselfAll, totalSharedSum.abs());

    if (totalSharedSum == 0) {
      totalSharedText = AppLocalizations.of(context)!.allDone;
      textColorAll = Theme.of(context).colorScheme.onSurface;
    }
    textColorAll = Theme.of(context).colorScheme.onSurface;

    sharedWidget.insert(
        0,
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            totalSharedText,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(color: textColorAll),
          ),
        ));

    return Column(children: sharedWidget);
  }
}
