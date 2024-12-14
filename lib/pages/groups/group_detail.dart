import 'package:deun/pages/groups/group_detail_list.dart';
import 'package:deun/pages/groups/group_list.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../provider.dart';

import 'group_model.dart';

class GroupDetail extends ConsumerStatefulWidget {
  const GroupDetail({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends ConsumerState<GroupDetail> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> updateExpenseList() async {
    return ref.refresh(groupDetailProvider(widget.group.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Group> groupDetail = ref.watch(groupDetailProvider(widget.group.id));

    return Scaffold(
        body: Hero(
            tag: "group_card_${widget.group.id}",
            child: Material(
                child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          SliverAppBar(
                            expandedHeight: 120,
                            flexibleSpace: FlexibleSpaceBar(
                              title: Text(widget.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              centerTitle: false,
                            ),
                            floating: true, // Your appBar appears immediately
                            snap: true, // Your appBar displayed %100 or %0
                            pinned: true, // Your appBar pinned to top
                          ),
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                switch (groupDetail) {
                                  AsyncData(:final value) => Padding(
                                      padding: const EdgeInsets.fromLTRB(16.0, 5.0, 16.0, 5.0),
                                      child: GroupShareWidget(group: value)),
                                  _ => const Padding(
                                      padding: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                                      child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                                height: 25,
                                                width: 250,
                                                child: ShimmerCardList(
                                                  height: 20,
                                                  listEntryLength: 1,
                                                )),
                                            SizedBox(
                                                height: 25,
                                                width: 250,
                                                child: ShimmerCardList(
                                                  height: 15,
                                                  listEntryLength: 1,
                                                )),
                                          ])),
                                }
                              ],
                            ),
                          ),
                        ],
                    body: GroupDetailList(group: widget.group)))),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              GoRouter.of(context).push("/group/details/expense", extra: {'group': widget.group, 'expense': null}).then(
                (value) async {
                  await updateExpenseList();
                },
              );
            },
            label: Text(AppLocalizations.of(context)!.addNewExpense),
            icon: const Icon(Icons.add)));
  }
}
