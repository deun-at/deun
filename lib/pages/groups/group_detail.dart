import 'package:deun/pages/groups/group_detail_list.dart';
import 'package:deun/pages/groups/group_list.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final ScrollController _scrollController = ScrollController();
  int oldLength = 0;
  bool _showText = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_showText) {
        setState(() {
          _showText = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_showText) {
        setState(() {
          _showText = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: NestedScrollView(
            physics: const BouncingScrollPhysics(),
            controller: _scrollController,
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
                        Consumer(
                          builder: (ctx, watch, child) {
                            final isLoading = ref.watch(groupDetailNotifierProvider(widget.group.id)).isLoading;
                            final groupDetail = ref.watch(groupDetailNotifierProvider(widget.group.id)).value;

                            if (isLoading || groupDetail == null) {
                              return const Padding(
                                  padding: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                                  child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                            height: 25,
                                            width: 250,
                                            child: ShimmerCardList(
                                              height: 15,
                                              listEntryLength: 1,
                                            )),
                                        SizedBox(
                                            height: 37,
                                            width: 250,
                                            child: ShimmerCardList(
                                              height: 10,
                                              listEntryLength: 2,
                                            )),
                                      ]));
                            }

                            return Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 5.0, 16.0, 5.0),
                                child: GroupShareWidget(group: groupDetail));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
            body: GroupDetailList(group: widget.group)),
        floatingActionButton:
            Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
          FloatingActionButton.small(
            onPressed: () {
              GoRouter.of(context).push("/group/details/payment", extra: {'group': widget.group});
            },
            child: const Icon(Icons.credit_card),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
              heroTag: "floating_action_button_main",
              extendedIconLabelSpacing: _showText ? 10 : 0,
              extendedPadding: _showText ? null : const EdgeInsets.all(16),
              onPressed: () {
                GoRouter.of(context).push("/group/details/expense", extra: {'group': widget.group, 'expense': null});
              },
              label: AnimatedSize(
                duration: Durations.short4,
                child: _showText ? Text(AppLocalizations.of(context)!.addNewExpense) : const Text(""),
              ),
              icon: const Icon(Icons.add))
        ]));
  }
}
