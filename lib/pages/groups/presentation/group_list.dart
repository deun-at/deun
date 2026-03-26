import 'dart:io';

import 'package:deun/constants.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/native_ad_block.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/shimmer_card_list.dart';
import '../provider/group_list.dart';
import 'group_list_item.dart';
import '../data/group_model.dart';

class GroupList extends ConsumerStatefulWidget {
  const GroupList({super.key});

  @override
  ConsumerState<GroupList> createState() => _GroupListState();
}

class _GroupListState extends ConsumerState<GroupList> {
  final ScrollController _scrollController = ScrollController();
  String groupListFilter = "active";
  Widget? _adBlock;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _adBlock = SizedBox();
    } else {
      _adBlock = NativeAdBlock(
        adUnitId: Platform.isAndroid
            ? MobileAdMobs.androidGroupList.value
            : MobileAdMobs.iosGroupList.value,
      );
    }
  }

  Future<void> updateGroupList() async {
    ref
        .read(groupListProvider(groupListFilter).notifier)
        .reload(groupListFilter);
  }

  @override
  Widget build(BuildContext context) {
    final groupList = ref.watch(groupListProvider(groupListFilter));

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.medium(
            title: Text(
              AppLocalizations.of(context)!.groups,
              style: GoogleFonts.robotoSerif(
                textStyle: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
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
                      label: Text(
                        AppLocalizations.of(
                          context,
                        )!.groupListFilter(GroupListFilter.values[index].value),
                      ),
                      selected:
                          groupListFilter ==
                          GroupListFilter.values[index].value,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            groupListFilter =
                                GroupListFilter.values[index].value;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        body: switch (groupList) {
          AsyncData(:final value) =>
            value.isEmpty
                ? EmptyListWidget(
                    label: AppLocalizations.of(context)!.groupNoEntries,
                    onRefresh: () => updateGroupList(),
                  )
                : RefreshIndicator(
                    onRefresh: () => updateGroupList(),
                    child: GroupCardListView(
                      shrinkWrap: true,
                      adBlock: _adBlock,
                      groupList: value,
                      addSpacer: true,
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        // Access the Group instance
                        Group group = value[index];
                        return GroupListItem(
                          key: ValueKey(group.id),
                          group: group,
                        );
                      },
                    ),
                  ),
          AsyncError() => EmptyListWidget(
            label: AppLocalizations.of(context)!.groupNoEntries,
            onRefresh: () async {
              await updateGroupList();
            },
          ),
          _ => ShimmerCardList(height: 100, listEntryLength: 8),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "floating_action_button_main",
        onPressed: () {
          GoRouter.of(context).push("/group/edit");
        },
        label: Text(AppLocalizations.of(context)!.addNewGroup),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
