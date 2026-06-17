import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/presentation/friend_balance.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/friendship_list.dart';
import '../../../widgets/shimmer_card_list.dart';
import '../../../widgets/theme_builder.dart';

class FriendList extends ConsumerStatefulWidget {
  const FriendList({super.key});

  @override
  ConsumerState<FriendList> createState() => _FriendListState();
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (friendshipProvider) {
          AsyncData(:final value) => value.acceptedFriends.isEmpty &&
                  value.pendingIncomingRequests.isEmpty &&
                  value.pendingOutgoingRequests.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FriendsHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: EmptyListWidget(
                        icon: Icons.group_outlined,
                        label: l10n.friendsNoEntries,
                        onRefresh: updateFriendshipList,
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: updateFriendshipList,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    children: [
                      _FriendsHeader(),
                      const SizedBox(height: 12),
                      if (value.pendingIncomingRequests.isNotEmpty) ...[
                        SectionLabel(l10n.friendRequests(value.pendingIncomingRequests.length)),
                        const SizedBox(height: 8),
                        for (final friendship in value.pendingIncomingRequests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _IncomingRequestCard(
                              friendship: friendship,
                              onAccept: () => _acceptFriendRequest(
                                  friendship.user.email, friendship.user.displayName),
                              onDecline: () => _declineFriendRequest(
                                  friendship.user.email, friendship.user.displayName),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (value.pendingOutgoingRequests.isNotEmpty) ...[
                        SectionLabel(l10n.pendingRequests(value.pendingOutgoingRequests.length)),
                        const SizedBox(height: 8),
                        for (final friendship in value.pendingOutgoingRequests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _OutgoingRequestCard(
                              friendship: friendship,
                              onCancel: () => _cancelFriendRequest(
                                  friendship.user.email, friendship.user.displayName),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (value.acceptedFriends.isNotEmpty) ...[
                        SectionLabel(l10n.friends),
                        const SizedBox(height: 8),
                        for (final friendship in value.acceptedFriends)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FriendCard(
                              friendship: friendship,
                              // TODO(E4-T2): replace with the redesigned friend sheet.
                              onTap: () =>
                                  openFriendshipDialog(context, friendship.user, friendship),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
          AsyncError() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FriendsHeader(),
                const SizedBox(height: 8),
                Expanded(
                  child: EmptyListWidget(
                    icon: Icons.group_outlined,
                    label: l10n.friendsNoEntries,
                    onRefresh: updateFriendshipList,
                  ),
                ),
              ],
            ),
          _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FriendsHeader(),
                const Expanded(
                  child: ShimmerCardList(height: 70, listEntryLength: 12),
                ),
              ],
            ),
        },
      ),
    );
  }

  void openFriendshipDialog(BuildContext modalContext, SupaUser user, Friendship friendship) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final bool paypalEnabled = user.paypalMe != null && user.paypalMe!.isNotEmpty;
    final bool ibanEnabled = user.iban != null && user.iban!.isNotEmpty;

    Color shareAmountColor = colorScheme.onSurface;
    if (friendship.shareAmount < 0) {
      shareAmountColor = semantic.danger;
    } else if (friendship.shareAmount > 0) {
      shareAmountColor = semantic.success;
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
                    MemberAvatar(name: user.displayName, colorKey: user.email, radius: 24),
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
                    final paypalUri = Uri.parse("https://www.paypal.me/${user.paypalMe}/${friendship.shareAmount.abs()}");
                    bool launched = false;
                    try {
                      launched = await launchUrl(paypalUri);
                    } catch (e) {
                      debugPrint('Could not launch PayPal link: $e');
                    }
                    if (!launched && context.mounted) {
                      showSnackBar(context, AppLocalizations.of(context)!.generalError);
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
                      await GroupRepository.payBackAll(context, user.email);
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

/// Screen title with QR + person-add actions.
class _FriendsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.friends,
              style: textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => GoRouter.of(context).push('/friend/qr'),
            tooltip: l10n.qr,
            icon: const Icon(Icons.qr_code),
          ),
          IconButton(
            onPressed: () => GoRouter.of(context).push('/friend/add'),
            tooltip: l10n.addFriends,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
    );
  }
}

/// A common avatar + name/username row used by the friend / request cards.
class _FriendIdentity extends StatelessWidget {
  const _FriendIdentity({required this.user});

  final SupaUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        MemberAvatar(name: user.displayName, colorKey: user.email),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.displayName,
                style: textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.fullUsername,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Incoming friend request: identity + accept / decline actions.
class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.friendship,
    required this.onAccept,
    required this.onDecline,
  });

  final Friendship friendship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SoftCard(
      child: Row(
        children: [
          Expanded(child: _FriendIdentity(user: friendship.user)),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAccept,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_outlined, size: 18),
                const SizedBox(width: 5),
                Text(l10n.accept),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            onPressed: onDecline,
            tooltip: l10n.friendDecline,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Outgoing friend request: identity + cancel action.
class _OutgoingRequestCard extends StatelessWidget {
  const _OutgoingRequestCard({
    required this.friendship,
    required this.onCancel,
  });

  final Friendship friendship;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SoftCard(
      child: Row(
        children: [
          Expanded(child: _FriendIdentity(user: friendship.user)),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_disabled, size: 18),
                const SizedBox(width: 5),
                Text(l10n.cancel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An accepted friend: identity + a semantic balance pill. Tapping opens the
/// friend sheet (see [onTap]).
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friendship, required this.onTap});

  final Friendship friendship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = friendBalanceState(friendship.shareAmount);

    final String label;
    switch (state) {
      case BalanceState.owed:
        label = l10n.balanceOwed;
        break;
      case BalanceState.owe:
        label = l10n.balanceOwe;
        break;
      case BalanceState.settled:
        label = l10n.balanceSettled;
        break;
    }

    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: _FriendIdentity(user: friendship.user)),
          const SizedBox(width: 8),
          BalancePill(
            label: label,
            state: state,
            amount: state == BalanceState.settled ? null : friendship.shareAmount.abs(),
          ),
        ],
      ),
    );
  }
}
