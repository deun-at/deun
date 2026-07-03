import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/presentation/friend_balance.dart';
import 'package:deun/pages/friends/presentation/friend_detail_sheet.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/balance_pill.dart' show BalanceState;
import 'package:deun/widgets/restyle/deun_header.dart' show HeaderIconButton;
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/restyle/spaced_card_list.dart';
import 'package:deun/widgets/staggered_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../provider/friendship_list.dart';
import '../../../widgets/shimmer_card_list.dart';

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

  Widget _buildFriendListView(
    BuildContext context,
    FriendshipListState value,
    AppLocalizations l10n,
  ) {
    final children = <Widget>[
      _FriendsHeader(),
      const SizedBox(height: 12),
      // SPACED list preset (F143): sections render their cards through
      // spacedCardItems so every card gap matches the group list's rhythm.
      if (value.pendingIncomingRequests.isNotEmpty) ...[
        SectionLabel(l10n.friendRequests(value.pendingIncomingRequests.length)),
        const SizedBox(height: 8),
        ...spacedCardItems([
          for (final friendship in value.pendingIncomingRequests)
            _IncomingRequestCard(
              friendship: friendship,
              onAccept: () =>
                  _acceptFriendRequest(friendship.user.email, friendship.user.displayName),
              onDecline: () =>
                  _declineFriendRequest(friendship.user.email, friendship.user.displayName),
            ),
        ]),
        const SizedBox(height: 16),
      ],
      if (value.pendingOutgoingRequests.isNotEmpty) ...[
        SectionLabel(l10n.pendingRequests(value.pendingOutgoingRequests.length)),
        const SizedBox(height: 8),
        ...spacedCardItems([
          for (final friendship in value.pendingOutgoingRequests)
            _OutgoingRequestCard(
              friendship: friendship,
              onCancel: () =>
                  _cancelFriendRequest(friendship.user.email, friendship.user.displayName),
            ),
        ]),
        const SizedBox(height: 16),
      ],
      if (value.acceptedFriends.isNotEmpty) ...[
        SectionLabel(l10n.friends),
        const SizedBox(height: 8),
        ...spacedCardItems([
          for (final friendship in value.acceptedFriends)
            _FriendCard(
              friendship: friendship,
              onTap: () => openFriendDetailSheet(context, friendship),
            ),
        ]),
      ],
    ];

    final listView = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: staggeredChildren(context, children),
    );

    return RefreshIndicator(
      onRefresh: updateFriendshipList,
      child: MediaQuery.of(context).disableAnimations
          ? listView
          : AnimationLimiter(child: listView),
    );
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
              : _buildFriendListView(context, value, l10n),
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
}

/// Screen title with QR + person-add actions.
class _FriendsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 11, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.friends,
              style: textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          HeaderIconButton(
            onTap: () => GoRouter.of(context).push('/friend/qr'),
            tooltip: l10n.qr,
            icon: Icons.qr_code,
          ),
          const SizedBox(width: 8),
          HeaderIconButton(
            onTap: () => GoRouter.of(context).push('/friend/add'),
            tooltip: l10n.addFriends,
            icon: Icons.person_add,
            filled: true,
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
          PrimaryButton(
            label: l10n.accept,
            icon: Icons.person_add_outlined,
            onPressed: onAccept,
            compact: true,
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
          SecondaryButton(
            label: l10n.cancel,
            icon: Icons.person_add_disabled,
            foreground: colorScheme.error,
            onPressed: onCancel,
            compact: true,
          ),
        ],
      ),
    );
  }
}

/// An accepted friend: identity + a plain semantic-colored balance label.
/// Tapping opens the friend sheet (see [onTap]).
///
/// v3 renders the friend-row balance as PLAIN text colored by state — green when
/// the friend owes you, red when you owe, neutral gray when settled — with no
/// filled chip/pill background (matches `Deun Redesign v3.dc.html` "All friends").
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friendship, required this.onTap});

  final Friendship friendship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final state = friendBalanceState(friendship.shareAmount);

    final String label;
    final Color balanceColor;
    final MoneySemantic moneySemantic;
    switch (state) {
      case BalanceState.owed:
        label = l10n.balanceOwed;
        balanceColor = semantic.success;
        moneySemantic = MoneySemantic.positive;
        break;
      case BalanceState.owe:
        label = l10n.balanceOwe;
        balanceColor = semantic.danger;
        moneySemantic = MoneySemantic.negative;
        break;
      case BalanceState.settled:
        label = l10n.balanceSettled;
        // Neutral muted-gray token (the warm onSurfaceVariant), brightness-aware
        // and a11y-checked — v3's settled gray.
        balanceColor = colorScheme.onSurfaceVariant;
        moneySemantic = MoneySemantic.neutral;
        break;
    }

    // v3 balance text: 13px / w600, the whole label tinted by state. No chip
    // background, no pill padding — plain semantic-colored text.
    final balanceStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: balanceColor,
          fontWeight: FontWeight.w600,
        );

    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: _FriendIdentity(user: friendship.user)),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: balanceStyle),
              if (state != BalanceState.settled) ...[
                const SizedBox(width: 6),
                MoneyText(
                  friendship.shareAmount.abs(),
                  semantic: moneySemantic,
                  style: balanceStyle,
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          // v3 ends an accepted-friend row in a muted chevron to signal it opens
          // the friend sheet (matches the group-list row pattern). `outline`
          // resolves the warm muted-gray token and flips with brightness.
          Icon(Icons.chevron_right, color: colorScheme.outline),
        ],
      ),
    );
  }
}
