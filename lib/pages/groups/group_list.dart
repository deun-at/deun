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
import 'group_list_item.dart';
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
      _adBox = const SizedBox();
      // _adBox = NativeAdBlock(
      //   adUnitId: Platform.isAndroid ? MobileAdMobs.androidGroupList.value : MobileAdMobs.iosGroupList.value,
      // );
    }
  }

  Future<void> updateGroupList() async {
    await ref
        .read(groupListNotifierProvider(groupListFilter).notifier)
        .reload(groupListFilter);
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
                          label: Text(AppLocalizations.of(context)!
                              .groupListFilter(GroupListFilter.values[index].value)),
                          selected:
                              groupListFilter == GroupListFilter.values[index].value,
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

                            if ((index == 5 ||
                                    (value.length < 6 && index == value.length - 1)) &&
                                _adBox != null) {
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
