import 'dart:io';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/native_ad_block.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../provider.dart';
import '../../widgets/shimmer_card_list.dart';
import 'group_model.dart';

class GroupList extends ConsumerStatefulWidget {
  const GroupList({super.key});

  @override
  ConsumerState<GroupList> createState() => _GroupListState();
}

class _GroupListState extends ConsumerState<GroupList> {
  final ScrollController _scrollController = ScrollController();
  String groupListFilter = "active";
  Widget? _adBox;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _adBox = SizedBox();
    } else {
      _adBox = NativeAdBlock(
        adUnitId: Platform.isAndroid ? MobileAdMobs.androidGroupList.value : MobileAdMobs.iosGroupList.value,
      );
    }
  }

  Future<void> updateGroupList() async {
    await ref.read(groupListNotifierProvider(groupListFilter).notifier).reload(groupListFilter);
  }

  @override
  Widget build(BuildContext context) {
    final groupList = ref.watch(groupListNotifierProvider(groupListFilter));

    return ScaffoldMessenger(
      key: groupListScaffoldMessengerKey,
      child: Scaffold(
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(AppLocalizations.of(context)!.groups),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: GroupListFilter.values.length,
                    itemBuilder: (context, index) {
                      double paddingLeft = 0;
                      if (index == 0) {
                        paddingLeft = 10;
                      }

                      return Padding(
                        padding: EdgeInsets.only(left: paddingLeft, right: 10),
                        child: FilterChip(
                          label:
                              Text(AppLocalizations.of(context)!.groupListFilter(GroupListFilter.values[index].value)),
                          selected: groupListFilter == GroupListFilter.values[index].value,
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () {
                                  groupListFilter = GroupListFilter.values[index].value;
                                },
                              );
                            }
                          },
                        ),
                      );
                    }),
              ),
            ),
          ],
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
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: value.length + 1,
                          itemBuilder: (context, index) {
                            if (index == value.length) {
                              return const SizedBox(height: 80);
                            }

                            Widget itemWidget;

                            // Access the Group instance
                            Group group = value[index];
                            GroupListItem groupListItem = GroupListItem(group: group);

                            if ((index == 5 || (value.length < 6 && index == value.length - 1)) && _adBox != null) {
                              itemWidget = Column(
                                children: [
                                  _adBox!,
                                  groupListItem,
                                ],
                              );
                            } else {
                              itemWidget = groupListItem;
                            }

                            return itemWidget;
                          },
                        ),
                      ),
                    ),
              AsyncError() => EmptyListWidget(
                  label: AppLocalizations.of(context)!.groupNoEntries,
                  onRefresh: () async {
                    await updateGroupList();
                  },
                ),
              _ => const ShimmerCardList(
                  height: 100,
                  listEntryLength: 8,
                ),
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: "floating_action_button_main",
          onPressed: () {
            GoRouter.of(context).push("/group/edit");
          },
          label: Text(AppLocalizations.of(context)!.addNewGroup),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class GroupListItem extends ConsumerStatefulWidget {
  const GroupListItem({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _GroupListItemState();
}

class _GroupListItemState extends ConsumerState<GroupListItem> {
  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    Color colorSeedValue = Color(widget.group.colorValue);

    return Hero(
      tag: "group_detail_${widget.group.id}",
      child: Theme(
        data: themeData.copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: colorSeedValue, brightness: themeData.brightness)),
        child: Builder(
          builder: (context) {
            ThemeData cardThemeData = Theme.of(context);
            ColorScheme cardColorScheme = cardThemeData.colorScheme;

            return Card(
              elevation: 5,
              shadowColor: Colors.transparent,
              surfaceTintColor: cardColorScheme.primary,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () {
                  ref.read(themeColorProvider.notifier).setColor(Color(widget.group.colorValue));
                  GoRouter.of(context).push("/group/details", extra: {'group': widget.group}).then(
                    (value) async {
                      ref.read(themeColorProvider.notifier).resetColor();
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
                              widget.group.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      GroupShareWidget(group: widget.group),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GroupShareWidget extends StatelessWidget {
  const GroupShareWidget({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    List<Widget> sharedWidget = group.groupSharesSummary
        .map(
          (String key, GroupSharesSummary e) {
            if (toNumber(e.shareAmount.abs()) == '0.00') {
              return MapEntry(key, const SizedBox());
            }

            Color textColor = Colors.red;
            String paidByYourself = "";
            if (e.shareAmount > 0) {
              paidByYourself = "yes";
              textColor = Colors.green;
            }

            return MapEntry(
              key,
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  AppLocalizations.of(context)!.groupDisplayAmount(e.displayName, paidByYourself, e.shareAmount.abs()),
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                ),
              ),
            );
          },
        )
        .entries
        .map((e) => e.value)
        .toList();

    String paidByYourselfAll = "";
    Color textColorAll = Colors.red;
    if (group.totalShareAmount > 0) {
      paidByYourselfAll = "yes";
      textColorAll = Colors.green;
    }

    String totalSharedText =
        AppLocalizations.of(context)!.groupDisplaySumAmount(paidByYourselfAll, group.totalShareAmount.abs());
    if (toNumber(group.totalShareAmount.abs()) == '0.00') {
      totalSharedText = AppLocalizations.of(context)!.allDone;
      textColorAll = Theme.of(context).colorScheme.onSurface;
    }

    sharedWidget.insert(
      0,
      Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          AppLocalizations.of(context)!.totalExpensesAmount(group.totalExpenses.abs()),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );

    sharedWidget.insert(
      1,
      Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          totalSharedText,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(color: textColorAll),
        ),
      ),
    );

    return Column(children: sharedWidget);
  }
}
