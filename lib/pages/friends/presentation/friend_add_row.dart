import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';

/// One result/contact row on the Add friend screen (Screen 15a): a
/// [MemberAvatar], the display name, the `@username#code` handle, and a pill
/// button that reads **Add** (actionable) or **Requested** (passive) once a
/// request has been sent.
class FriendAddRow extends StatelessWidget {
  const FriendAddRow({
    super.key,
    required this.user,
    required this.isRequested,
    required this.onRequest,
  });

  final SupaUser user;

  /// When true the row shows the passive "Requested" pill instead of "Add".
  final bool isRequested;

  /// Invoked when the "Add" pill is tapped (no-op once requested).
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          MemberAvatar(
            name: user.displayName,
            colorKey: user.email,
            radius: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.fullUsername,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _AddPill(isRequested: isRequested, onRequest: onRequest),
        ],
      ),
    );
  }
}

/// The rounded Add / Requested pill. "Add" is a filled primary action; once
/// requested it becomes a muted, non-interactive chip.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.isRequested, required this.onRequest});

  final bool isRequested;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isRequested) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          l10n.addFriendshipRequestedButton,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return PrimaryButton(
      label: l10n.add,
      onPressed: onRequest,
      compact: true,
    );
  }
}
