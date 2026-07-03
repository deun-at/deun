import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/presentation/friend_add_row.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

/// Restyled live search-results section (Screen 15a): a [SectionLabel] header
/// over a [SoftCard] of [FriendAddRow]s. Renders nothing until the user types.
class SearchResultList extends StatelessWidget {
  final List<SupaUser> searchResults;
  final Function(String userEmail, String displayName) onRequest;
  final String searchText;
  final bool isLoading;
  final bool isAmbiguousUsername;

  /// Emails already requested in this session — flips a row to "Requested".
  final Set<String> requestedEmails;

  const SearchResultList({
    super.key,
    required this.searchResults,
    required this.onRequest,
    required this.searchText,
    required this.isLoading,
    this.isAmbiguousUsername = false,
    this.requestedEmails = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (searchText.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: SectionLabel(l10n.addFriendshipSearchResult),
    );

    Widget body;
    if (isLoading) {
      body = const ShimmerCardList(
        height: 64,
        listEntryLength: 2,
        shape: ShimmerShape.row,
      );
    } else if (isAmbiguousUsername) {
      body = _MessageCard(message: l10n.addFriendshipAmbiguousUsername);
    } else if (searchResults.isEmpty) {
      body = _MessageCard(message: l10n.addFriendshipNoResult);
    } else {
      body = SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final user in searchResults)
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, body],
      ),
    );
  }
}

/// A soft card holding a single centered status message (empty / ambiguous).
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
