import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../provider.dart';
import '../../widgets/shimmer_card_list.dart';

class FriendList extends ConsumerStatefulWidget {
  const FriendList({super.key});

  @override
  ConsumerState<FriendList> createState() => _FriendListState();
}

class _FriendListState extends ConsumerState<FriendList> {
  Future<void> updateFriendshipList() async {
    return ref.read(friendshipListNotifierProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Friendship>> friendshipProvider = ref.watch(friendshipListNotifierProvider);

    return ScaffoldMessenger(
      key: friendListScaffoldMessengerKey,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(AppLocalizations.of(context)!.friends),
              actions: [
                IconButton(
                    onPressed: () {
                      GoRouter.of(context).push("/friend/add");
                    },
                    icon: const Icon(Icons.person_add_outlined))
              ],
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
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          Friendship friendship = value[index];
                          User user = friendship.user;

                          Color shareAmountColor = Theme.of(context).colorScheme.onSurface;
                          if (friendship.shareAmount < 0) {
                            shareAmountColor = Colors.red;
                          } else if (friendship.shareAmount > 0) {
                            shareAmountColor = Colors.green;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(user.displayName),
                                subtitle: Text(user.email),
                                trailing: Text(
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: shareAmountColor),
                                    AppLocalizations.of(context)!.toCurrency(friendship.shareAmount)),
                                onTap: () {
                                  openFriendshipDialog(context, user, friendship);
                                },
                              ),
                              index < value.length - 1 ? const Divider(height: 0) : const SizedBox(),
                            ],
                          );
                        },
                      ),
                    ),
              AsyncError() => EmptyListWidget(
                  label: AppLocalizations.of(context)!.friendsNoEntries,
                  onRefresh: () async {
                    await updateFriendshipList();
                  },
                ),
              _ => const ShimmerCardList(
                  height: 70,
                  listEntryLength: 20,
                ),
            },
          ),
        ),
      ),
    );
  }

  void openFriendshipDialog(BuildContext modalContext, User user, Friendship friendship) {
    Color activeColor = Theme.of(context).colorScheme.onSurface;
    Color disabledColor = Theme.of(context).colorScheme.outline;

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
          Divider(),
          ...(friendship.shareAmount < -0.01
              ? [
                  SimpleDialogOption(
                    child: Text(
                      AppLocalizations.of(context)!.payBackDialog(user.displayName, friendship.shareAmount.abs()),
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () async {
                      if (user.paypalMe == null || user.paypalMe!.isEmpty) {
                        return;
                      }
                      if (!await launchUrl(
                          Uri.parse("https://www.paypal.me/${user.paypalMe}/${friendship.shareAmount.abs()}"))) {
                        throw Exception(
                            'Could not launch https://www.paypal.me/${user.paypalMe}/${friendship.shareAmount.abs()}');
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.payBackDialogPaypal,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: user.paypalMe == null || user.paypalMe!.isEmpty ? disabledColor : activeColor),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.payments_outlined,
                          color: user.paypalMe == null || user.paypalMe!.isEmpty ? disabledColor : activeColor,
                        ),
                      ],
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      if (user.iban == null || user.iban!.isEmpty) {
                        return;
                      }

                      Clipboard.setData(ClipboardData(text: user.iban as String)).then((_) {});
                    },
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.payBackDialogIban,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(color: user.iban == null || user.iban!.isEmpty ? disabledColor : activeColor),
                        ),
                        const Spacer(),
                        Icon(Icons.credit_card,
                            color: user.iban == null || user.iban!.isEmpty ? disabledColor : activeColor),
                      ],
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () async {
                      try {
                        await Group.payBackAll(context, user.email, friendship.shareAmount.abs());
                        if (context.mounted) {
                          showSnackBar(context, friendListScaffoldMessengerKey,
                              AppLocalizations.of(context)!.payBackSuccess(user.email, friendship.shareAmount.abs()));
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                        if (context.mounted) {
                          showSnackBar(
                              context, friendListScaffoldMessengerKey, AppLocalizations.of(context)!.payBackError);
                        }
                      } finally {
                        if (context.mounted) {
                          Navigator.pop(context); // Close friendship dialog
                        }
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.payBackDialogDone,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: activeColor),
                        ),
                        const Spacer(),
                        Icon(Icons.credit_score, color: activeColor),
                      ],
                    ),
                  ),
                  Divider(),
                ]
              : []),
          SimpleDialogOption(
            onPressed: () {
              openRemoveFriendDialog(user);
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
          Divider(),
          SizedBox(height: 10),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context); // Close friendship dialog
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

  void openRemoveFriendDialog(User user) {
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
