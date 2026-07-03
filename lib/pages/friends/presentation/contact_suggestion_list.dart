import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/presentation/friend_add_row.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

/// Restyled "From your contacts" section (Screen 15a): a [SectionLabel] with a
/// contacts glyph over a [SoftCard] of [FriendAddRow]s, plus an inline
/// permission prompt when contact access was denied.
class ContactSuggestionList extends StatelessWidget {
  final List<SupaUser> contactSuggestions;
  final Function(String userEmail, String displayName) onRequest;
  final bool isLoading;
  final bool contactPermissionDenied;
  final VoidCallback? onRequestPermission;

  /// Emails already requested in this session — flips a row to "Requested".
  final Set<String> requestedEmails;

  const ContactSuggestionList({
    super.key,
    required this.contactSuggestions,
    required this.onRequest,
    required this.isLoading,
    this.contactPermissionDenied = false,
    this.onRequestPermission,
    this.requestedEmails = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: SectionLabel(
        l10n.addFriendshipFromContacts,
        trailing: Icon(
          Icons.contacts_outlined,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget body;
    if (isLoading) {
      body = const ShimmerCardList(
        height: 64,
        listEntryLength: 3,
        shape: ShimmerShape.row,
      );
    } else if (contactSuggestions.isEmpty) {
      body = _ContactEmptyCard(
        contactPermissionDenied: contactPermissionDenied,
        onRequestPermission: onRequestPermission,
      );
    } else {
      body = SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final user in contactSuggestions)
              FriendAddRow(
                user: user,
                isRequested: requestedEmails
                    .any((e) => e.toLowerCase() == user.email.toLowerCase()),
                onRequest: () => onRequest(user.email, user.displayName),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, body],
      ),
    );
  }
}

/// Empty / permission-denied state for the contacts section.
class _ContactEmptyCard extends StatelessWidget {
  const _ContactEmptyCard({
    required this.contactPermissionDenied,
    required this.onRequestPermission,
  });

  final bool contactPermissionDenied;
  final VoidCallback? onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final showAllow = contactPermissionDenied && onRequestPermission != null;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addFriendshipContactNoResult,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addFriendshipContactPermissionSubtitle,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (showAllow) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SecondaryButton(
                label: l10n.addFriendshipContactOpenSettings,
                onPressed: onRequestPermission,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
