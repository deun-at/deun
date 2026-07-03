import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/user_avatar.dart';

class PendingRequestList extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRequests;
  final Function(String userEmail, String displayName) onAccept;
  final Function(String userEmail, String displayName) onDecline;
  final bool isLoading;

  const PendingRequestList({
    super.key,
    required this.pendingRequests,
    required this.onAccept,
    required this.onDecline,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    Widget title = ListTile(
      enabled: false,
      minTileHeight: 1,
      title: Padding(
        padding: const EdgeInsetsGeometry.only(top: 10),
        child: Text(
          AppLocalizations.of(context)!.addFriendshipPendingRequests,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );

    if (isLoading) {
      return Column(children: [
        title,
        const ShimmerCardList(
          height: 50,
          listEntryLength: 3,
          shape: ShimmerShape.row,
        ),
      ]);
    }

    List<Widget> widgets = List.empty(growable: true);

    if (pendingRequests.isEmpty || pendingRequests.first['email'] == null) {
      widgets.add(ListTile(
          title: Text(AppLocalizations.of(context)!.addFriendshipRequestNoResult)));
    } else {
      widgets.addAll(
        pendingRequests.map(
          (user) => _RequestCard(
            user: user,
            onAccept: onAccept,
            onDecline: onDecline,
          ),
        ),
      );
    }

    return Column(children: [title, CardColumn(children: widgets)]);
  }
}

/// Incoming friend-request card (v3 handoff — Friends → Friend Requests).
///
/// Layout: identity row (avatar + name + handle) with a full-width action row
/// below — a dominant [Accept] spanning the remaining width and a compact
/// square decline button beside it. Both use radius-11 per the prototype.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.user,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> user;
  final Function(String userEmail, String displayName) onAccept;
  final Function(String userEmail, String displayName) onDecline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(11);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(displayName: user['display_name'] ?? '', radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['display_name'],
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      fullUsernameFromJson(user),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              // Dominant Accept action spanning the remaining card width.
              Expanded(
                child: Material(
                  color: colorScheme.primary,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () => onAccept(user['email'], user['display_name']),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        l10n.accept,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Compact decline: warm-neutral square, muted glyph, radius-11.
              Material(
                color: colorScheme.surfaceContainer,
                borderRadius: radius,
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => onDecline(user['email'], user['display_name']),
                  child: SizedBox(
                    width: 44,
                    height: 40,
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
