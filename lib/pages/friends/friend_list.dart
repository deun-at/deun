import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';

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
    return ref.read(friendshipListNotifierProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Friendship>> friendshipProvider = ref.watch(friendshipListNotifierProvider);

    String currStatus = "";

    return ScaffoldMessenger(
        key: friendListScaffoldMessengerKey,
        child: Scaffold(
            body: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverAppBar.medium(
                        title: Text(AppLocalizations.of(context)!.friends),
                      ),
                    ],
                body: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: switch (friendshipProvider) {
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
                                itemCount: value.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == value.length) {
                                    return const SizedBox(height: 90);
                                  }

                                  Friendship friendship = value[index];
                                  User user = friendship.user;
                                  Widget leadingHeader = const SizedBox();
                                  Widget trailingButton = const SizedBox();
                                  Function? onPressCallback;

                                  if ((currStatus == "pending" || currStatus == "") &&
                                      friendship.status == "accepted") {
                                    leadingHeader = Padding(
                                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                                        child: Text(
                                          AppLocalizations.of(context)!.friends,
                                          style: Theme.of(context).textTheme.headlineSmall,
                                        ));
                                  } else if (currStatus == "" && friendship.status == "pending") {
                                    leadingHeader = Padding(
                                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                                        child: Text(
                                          AppLocalizations.of(context)!.friendsPending,
                                          style: Theme.of(context).textTheme.headlineSmall,
                                        ));
                                  }

                                  if (friendship.status == "pending") {
                                    if (friendship.isRequester) {
                                      trailingButton = IconButton.filledTonal(
                                        icon: const Icon(Icons.check),
                                        onPressed: () {
                                          Friendship.accepted(user.email);
                                          showSnackBar(context, friendListScaffoldMessengerKey,
                                              AppLocalizations.of(context)!.friendshipAccept(user.displayName));

                                          sendFriendAcceptNotification(context, {user.email});
                                        },
                                      );
                                    } else {
                                      trailingButton = IconButton.filledTonal(
                                        style: IconButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
                                        icon: const Icon(Icons.cancel_outlined),
                                        onPressed: () {
                                          Friendship.cancel(user.email);
                                          showSnackBar(context, friendListScaffoldMessengerKey,
                                              AppLocalizations.of(context)!.friendshipRequestCancel(user.displayName));
                                        },
                                      );
                                    }
                                  } else {
                                    Color shareAmountColor = Theme.of(context).colorScheme.onSurface;
                                    if (friendship.shareAmount < 0) {
                                      shareAmountColor = Colors.red;
                                    } else if (friendship.shareAmount > 0) {
                                      shareAmountColor = Colors.green;
                                    }
                                    trailingButton = Text(
                                        style:
                                            Theme.of(context).textTheme.bodyMedium!.copyWith(color: shareAmountColor),
                                        AppLocalizations.of(context)!.toCurrency(friendship.shareAmount));

                                    onPressCallback = () {
                                      openFriendshipDialog(context, user);
                                    };
                                  }

                                  currStatus = friendship.status;
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Padding(padding: const EdgeInsets.only(left: 15, right: 15), child: leadingHeader),
                                    ListTile(
                                      title: Text(user.displayName),
                                      subtitle: Text(user.email),
                                      trailing: trailingButton,
                                      onTap: () {
                                        if (onPressCallback != null) {
                                          onPressCallback();
                                        }
                                      },
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
                    })),
            floatingActionButton: SearchAnchor(
              viewHintText: AppLocalizations.of(context)!.addFriendshipSelectionEmpty,
              builder: (context, controller) {
                return FloatingActionButton.extended(
                    heroTag: "floating_action_button_friends",
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
            )));
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
    if (result.isEmpty) {
      return [
        ListTile(
          // ignore: use_build_context_synchronously
          title: Text(AppLocalizations.of(context)!.addFriendshipNoResult),
        )
      ];
    }

    return result.map((user) => ListTile(
          title: Text(user.displayName),
          subtitle: Text(user.email),
          onTap: () async {
            Friendship.request(user.email);
            showSnackBar(context, friendListScaffoldMessengerKey,
                AppLocalizations.of(context)!.friendshipRequestSent(user.displayName));
            controller.closeView("");

            sendFriendRequestNotification(context, {user.email});
          },
        ));
  }

  void openFriendshipDialog(BuildContext modalContext, User user) {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.friendshipDialogTitle(user.displayName)),
        children: [
          SimpleDialogOption(
            child: Text("${AppLocalizations.of(context)!.friendshipDialogEmail} ${user.email}"),
          ),
          user.firstName == null && user.lastName == null
              ? const SizedBox()
              : SimpleDialogOption(
                  child: Text(
                      "${AppLocalizations.of(context)!.friendshipDialogFullName} ${user.firstName ?? ''} ${user.lastName ?? ''}"),
                ),
          SizedBox(height: 20),
          SimpleDialogOption(
            onPressed: () {
              openRemoveFriendDialog(context, user);
            },
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.friendshipDialogRemoveAsFriend,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const Spacer(),
                Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
              ],
            ),
          ),
          SizedBox(height: 10),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context); // Close delete dialog
            },
            child: Text(
              AppLocalizations.of(context)!.close,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void openRemoveFriendDialog(BuildContext modalContext, User user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.removeFriend(user.displayName)),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.remove),
            onPressed: () async {
              try {
                Friendship.remove(user.email);
              } finally {
                Navigator.pop(context); // Close delete dialog
                Navigator.pop(context); // Close info dialog
                showSnackBar(context, friendListScaffoldMessengerKey,
                    AppLocalizations.of(context)!.friendRemoved(user.displayName));
              }
            },
          ),
        ],
      ),
    );
  }
}
