import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

import '../../provider.dart';
import '../../widgets/shimmer_card_list.dart';

class FriendList extends ConsumerStatefulWidget {
  const FriendList({super.key});

  @override
  ConsumerState<FriendList> createState() => _FriendListState();
}

class _FriendListState extends ConsumerState<FriendList> {
  final ScrollController _scrollController = ScrollController();
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

  Future<void> updateFriendshipList() async {
    return ref.refresh(friendshipListProvider.future);
  }

  Future<Iterable<Widget>> getUserSuggestions(SearchController controller) async {
    final String input = controller.value.text;

    if (input.isEmpty) {
      return [];
    }

    List<String> selectedUsers = List.empty(growable: true);

    var currFriendships = await Friendship.fetchData();

    for (var friendship in currFriendships) {
      selectedUsers.add(friendship.user.email);
    }
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    List<User> result = await User.fetchData(input, selectedUsers, 10);

    return result.map((user) => ListTile(
          title: Text(user.displayName),
          subtitle: Text(user.email),
          onTap: () {
            Friendship.request(user.email);
            controller.text = "";
          },
        ));
  }

  Future<void> updateFriendList() async {
    return ref.refresh(friendshipListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Friendship>> friendshipProvider = ref.watch(friendshipListProvider);
    String currStatus = "";

    supabase
        .channel('public:friendship')
        .onPostgresChanges(
            event: supabase_flutter.PostgresChangeEvent.all,
            schema: 'public',
            table: 'friendship',
            callback: (payload) {
              debugPrint("friendship changed");
              updateFriendList();
            })
        .subscribe();

    return Scaffold(
        body: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 120,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(AppLocalizations.of(context)!.friends, maxLines: 1, overflow: TextOverflow.ellipsis),
                      centerTitle: true,
                    ),
                    floating: true, // Your appBar appears immediately
                    snap: true, // Your appBar displayed %100 or %0
                    pinned: true, // Your appBar pinned to top
                  ),
                ],
            body: switch (friendshipProvider) {
              AsyncData(:final value) => value.isEmpty
                  ? EmptyListWidget(
                      label: AppLocalizations.of(context)!.friendsNoEntries,
                      onRefresh: () async {
                        updateFriendshipList();
                      })
                  : RefreshIndicator(
                      onRefresh: () async {
                        updateFriendshipList();
                      },
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          Friendship friendship = value[index];
                          User user = friendship.user;
                          Widget leadingHeader = const SizedBox();
                          Widget trailingButton = const SizedBox();

                          if ((currStatus == "pending" || currStatus == "") && friendship.status == "accepted") {
                            leadingHeader = Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  AppLocalizations.of(context)!.friends,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ));
                          } else if (currStatus == "" && friendship.status == "pending") {
                            leadingHeader = Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  AppLocalizations.of(context)!.friendsPending,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ));
                          }

                          if (friendship.status == "pending") {
                            if (friendship.isRequester) {
                              trailingButton = FilledButton(
                                child: Text(AppLocalizations.of(context)!.accept),
                                onPressed: () {
                                  Friendship.accepted(user.email);
                                },
                              );
                            } else {
                              trailingButton = FilledButton(
                                child: Text(AppLocalizations.of(context)!.cancel),
                                onPressed: () {
                                  Friendship.cancel(user.email);
                                },
                              );
                            }
                          } else {
                            trailingButton = FilledButton(
                              child: Text(AppLocalizations.of(context)!.remove),
                              onPressed: () {
                                Friendship.remove(user.email);
                              },
                            );
                          }

                          currStatus = friendship.status;
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.only(left: 15, right: 15), child: leadingHeader),
                            ListTile(
                              title: Text(user.displayName),
                              subtitle: Text(user.email),
                              trailing: trailingButton,
                              onTap: () {},
                            ),
                            const Divider(height: 0),
                          ]);
                        },
                      )),
              AsyncError() => EmptyListWidget(
                  label: AppLocalizations.of(context)!.friendsNoEntries,
                  onRefresh: () async {
                    await updateFriendshipList();
                  }),
              _ => const ShimmerCardList(
                  height: 70,
                  listEntryLength: 20,
                ),
            }),
        floatingActionButton: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.groupMemberSelectionEmpty,
          builder: (context, controller) {
            return FloatingActionButton.extended(
                heroTag: "floating_action_button_main",
                extendedIconLabelSpacing: _showText ? 10 : 0,
                extendedPadding: _showText ? null : const EdgeInsets.all(16),
                onPressed: () {
                  controller.openView();
                },
                label: AnimatedSize(
                  duration: Durations.short4,
                  child: _showText ? Text(AppLocalizations.of(context)!.requestFriendship) : const Text(""),
                ),
                icon: const Icon(Icons.person_add_outlined));
          },
          suggestionsBuilder: (context, controller) {
            return getUserSuggestions(controller);
          },
        ));
  }
}
