import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/expense_model.dart';
import 'package:deun/pages/groups/group_detail_list.dart';
import 'package:deun/pages/groups/group_list.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:deun/l10n/app_localizations.dart';
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
  final SearchController _searchController = SearchController();
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
    return ScaffoldMessenger(
      key: groupDetailScaffoldMessengerKey,
      child: Scaffold(
        body: Hero(
          tag: "group_detail_${widget.group.id}",
          child: Material(
            child: NotificationListener<ScrollUpdateNotification>(
              child: NestedScrollView(
                physics: const BouncingScrollPhysics(),
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar.medium(
                    title: Text(widget.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    actions: [
                      IconButton(
                        onPressed: () {
                          GoRouter.of(context).push("/group/edit", extra: {'group': widget.group});
                        },
                        icon: const Icon(Icons.edit),
                      )
                    ],
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
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 5.0, 16.0, 5.0),
                                child: GroupShareWidget(group: groupDetail));
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(10, 10, 10, 5),
                          child: SearchAnchor.bar(
                            searchController: _searchController,
                            barElevation: WidgetStateProperty.all(0),
                            barBackgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
                            barHintText: AppLocalizations.of(context)!.expensesSearchTitle,
                            suggestionsBuilder: (context, controller) {
                              if (controller.text.isEmpty) {
                                return <Widget>[
                                  ListTile(
                                    // ignore: use_build_context_synchronously
                                    title: Text(AppLocalizations.of(context)!.expensesSearchDescription),
                                  )
                                ];
                              }
                              return getExpenseSuggestions(controller, widget.group);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                body: GroupDetailList(group: widget.group),
              ),
              onNotification: (ScrollUpdateNotification notification) {
                final FocusScopeNode currentScope = FocusScope.of(context);
                if (notification.dragDetails != null && !currentScope.hasPrimaryFocus && currentScope.hasFocus) {
                  FocusManager.instance.primaryFocus?.unfocus();
                }
                return false;
              },
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<Iterable<Widget>> getExpenseSuggestions(SearchController controller, Group group) async {
    final String input = controller.value.text;

    if (input.isEmpty) {
      return [];
    }

    List<Expense> result = await Expense.fetchData(group.id, 0, 9, input);
    if (result.isEmpty) {
      return [
        ListTile(
          // ignore: use_build_context_synchronously
          title: Text(AppLocalizations.of(context)!.expensesSearchEmpty),
        )
      ];
    }

    return result.map(
      (expense) {
        double expenseSum = expense.expenseEntries.values.fold<double>(0, (sum, expense) => sum + expense.amount);

        return ListTile(
          title: Text(expense.name),
          subtitle: Text(AppLocalizations.of(context)!.toCurrency(expenseSum)),
          trailing: Text(formatDate(expense.expenseDate)),
          onTap: () async {
            controller.closeView("");
            GoRouter.of(context).push("/group/details/expense", extra: {'group': group, 'expense': expense});
          },
        );
      },
    );
  }
}
