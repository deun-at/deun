import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/friendship_list.dart';
import '../../../widgets/shimmer_card_list.dart';

class FriendList extends ConsumerStatefulWidget {
  const FriendList({super.key});

  @override
  ConsumerState<FriendList> createState() => _FriendListState();
}

Color _avatarColor(String name) {
  const colors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.teal, Colors.green,
    Colors.orange, Colors.brown,
  ];
  return colors[name.hashCode.abs() % colors.length];
}

class _FriendListState extends ConsumerState<FriendList> {
  Future<void> updateFriendshipList() async {
    return ref.read(friendshipListProvider.notifier).reload();
  }

  Future<void> _acceptFriendRequest(String email, String displayName) async {
    try {
      await FriendshipRepository.accepted(email);
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.friendshipAccept(displayName));
      sendFriendAcceptNotification(context, {email});
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    }
  }

  Future<void> _declineFriendRequest(String email, String displayName) async {
    try {
      await FriendshipRepository.decline(email);
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.friendshipRequestDecline(displayName));
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    }
  }

  Future<void> _cancelFriendRequest(String email, String displayName) async {
    try {
      await FriendshipRepository.cancel(email);
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.friendshipRequestCancel(displayName));
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FriendshipListState> friendshipProvider = ref.watch(friendshipListProvider);

    ThemeData themeData = Theme.of(context);
    ColorScheme colorScheme = themeData.colorScheme;

    return Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(
                AppLocalizations.of(context)!.friends,
                style: GoogleFonts.robotoSerif(
                  textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    GoRouter.of(context).push('/friend/qr');
                  },
                  tooltip: AppLocalizations.of(context)!.qr,
                  icon: const Icon(Icons.qr_code),
                ),
                IconButton(
                  onPressed: () {
                    GoRouter.of(context).push("/friend/add");
                  },
                  icon: const Icon(Icons.person_add_outlined),
                ),
              ],
            ),
          ],
          body: switch (friendshipProvider) {
            AsyncData(:final value) =>
              value.acceptedFriends.isEmpty && value.pendingIncomingRequests.isEmpty && value.pendingOutgoingRequests.isEmpty
                  ? EmptyListWidget(
                      icon: Icons.people_outlined,
                      label: AppLocalizations.of(context)!.friendsNoEntries,
                      onRefresh: () => updateFriendshipList(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => updateFriendshipList(),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (value.pendingIncomingRequests.isNotEmpty) ...[
                            _buildPendingRequestsSection(value.pendingIncomingRequests, colorScheme),
                          ],
                          if (value.pendingOutgoingRequests.isNotEmpty) ...[
                            _buildOutgoingRequestsSection(value.pendingOutgoingRequests, colorScheme),
                          ],
                          if (value.acceptedFriends.isNotEmpty) ...[
                            ListTile(
                              enabled: false,
                              minTileHeight: 1,
                              title: Padding(
                                padding: EdgeInsetsGeometry.only(top: 10),
                                child: Text(
                                  AppLocalizations.of(context)!.friends,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            CardListView(
                              color: colorScheme.surfaceContainerLowest,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: value.acceptedFriends.length,
                              itemBuilder: (context, index) {
                                Friendship friendship = value.acceptedFriends[index];
                                SupaUser user = friendship.user;

                                Color shareAmountColor = Theme.of(context).colorScheme.onSurface;
                                if (friendship.shareAmount < 0) {
                                  shareAmountColor = Colors.red;
                                } else if (friendship.shareAmount > 0) {
                                  shareAmountColor = Colors.green;
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: _avatarColor(user.displayName),
                                    child: Text(
                                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(user.displayName),
                                  subtitle: Text(user.fullUsername),
                                  trailing: Text(
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: shareAmountColor),
                                    AppLocalizations.of(context)!.toCurrency(friendship.shareAmount),
                                  ),
                                  onTap: () {
                                    openFriendshipDialog(context, user, friendship);
                                  },
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            AsyncError() => EmptyListWidget(
              icon: Icons.people_outlined,
              label: AppLocalizations.of(context)!.friendsNoEntries,
              onRefresh: () async {
                await updateFriendshipList();
              },
            ),
            _ => const ShimmerCardList(height: 70, listEntryLength: 25),
          },
        ),
    );
  }

  Widget _buildPendingRequestsSection(List<Friendship> pendingRequests, ColorScheme colorScheme) {
    return _buildRequestSection(
      title: AppLocalizations.of(context)!.friendRequests(pendingRequests.length),
      requests: pendingRequests,
      trailingBuilder: (user) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => _acceptFriendRequest(user.email, user.displayName),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_outlined, size: 18),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context)!.accept),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            onPressed: () => _declineFriendRequest(user.email, user.displayName),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestsSection(List<Friendship> outgoingRequests, ColorScheme colorScheme) {
    return _buildRequestSection(
      title: AppLocalizations.of(context)!.pendingRequests(outgoingRequests.length),
      requests: outgoingRequests,
      trailingBuilder: (user) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        onPressed: () => _cancelFriendRequest(user.email, user.displayName),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_disabled, size: 18, color: colorScheme.onError),
            const SizedBox(width: 5),
            Text(AppLocalizations.of(context)!.cancel),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSection({
    required String title,
    required List<Friendship> requests,
    required Widget Function(SupaUser user) trailingBuilder,
  }) {
    return Column(
      children: [
        ListTile(
          enabled: false,
          minTileHeight: 1,
          title: Padding(
            padding: EdgeInsetsGeometry.only(top: 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        CardColumn(
          children: requests.map((friendship) {
            SupaUser user = friendship.user;
            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: _avatarColor(user.displayName),
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.fullUsername),
              trailing: trailingBuilder(user),
            );
          }).toList(),
        ),
      ],
    );
  }

  void openFriendshipDialog(BuildContext modalContext, SupaUser user, Friendship friendship) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool paypalEnabled = user.paypalMe != null && user.paypalMe!.isNotEmpty;
    final bool ibanEnabled = user.iban != null && user.iban!.isNotEmpty;

    Color shareAmountColor = colorScheme.onSurface;
    if (friendship.shareAmount < 0) {
      shareAmountColor = Colors.red;
    } else if (friendship.shareAmount > 0) {
      shareAmountColor = Colors.green;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _avatarColor(user.displayName),
                      child: Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: Theme.of(context).textTheme.titleMedium),
                          Text(user.fullUsername, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                          if (user.firstName != null || user.lastName != null)
                            Text(
                              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.toCurrency(friendship.shareAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: shareAmountColor),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Payment actions
              if (friendship.shareAmount < -0.01) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)!.payBackDialog(user.displayName, friendship.shareAmount.abs()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.payments_outlined, color: paypalEnabled ? colorScheme.onSurface : colorScheme.outline),
                  title: Text(AppLocalizations.of(context)!.payBackDialogPaypal),
                  enabled: paypalEnabled,
                  onTap: () async {
                    if (!await launchUrl(
                      Uri.parse("https://www.paypal.me/${user.paypalMe}/${friendship.shareAmount.abs()}"),
                    )) {
                      throw Exception(
                        'Could not launch https://www.paypal.me/${user.paypalMe}/${friendship.shareAmount.abs()}',
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.credit_card, color: ibanEnabled ? colorScheme.onSurface : colorScheme.outline),
                  title: Text(AppLocalizations.of(context)!.payBackDialogIban),
                  enabled: ibanEnabled,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: user.iban as String)).then((_) {});
                  },
                ),
                ListTile(
                  leading: Icon(Icons.credit_score, color: colorScheme.onSurface),
                  title: Text(AppLocalizations.of(context)!.payBackDialogDone),
                  onTap: () async {
                    try {
                      await GroupRepository.payBackAll(context, user.email, friendship.shareAmount.abs());
                      if (context.mounted) {
                        showSnackBar(
                          context,
                          AppLocalizations.of(context)!.payBackSuccess(user.fullUsername, friendship.shareAmount.abs()),
                        );
                      }
                    } catch (e) {
                      debugPrint(e.toString());
                      if (context.mounted) {
                        showSnackBar(
                          context,
                          AppLocalizations.of(context)!.payBackError,
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
                const Divider(),
              ],
              // Remove friend
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: colorScheme.error),
                title: Text(
                  AppLocalizations.of(context)!.friendshipDialogRemoveAsFriend,
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  openRemoveFriendDialog(context, user);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void openRemoveFriendDialog(BuildContext sheetContext, SupaUser user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(AppLocalizations.of(dialogContext)!.removeFriend(user.displayName)),
        actions: <Widget>[
          TextButton(child: Text(AppLocalizations.of(dialogContext)!.cancel), onPressed: () => Navigator.pop(dialogContext)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(dialogContext)!.remove),
            onPressed: () async {
              try {
                await FriendshipRepository.remove(user.email);
                if (dialogContext.mounted) {
                  showSnackBar(
                    dialogContext,
                    AppLocalizations.of(dialogContext)!.friendRemoved(user.displayName),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  showSnackBar(dialogContext, AppLocalizations.of(dialogContext)!.generalError);
                }
              } finally {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Close delete dialog
                }
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext); // Close info sheet
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
