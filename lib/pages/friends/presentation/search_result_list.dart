import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/user_avatar.dart';

class SearchResultList extends StatelessWidget {
  final List<SupaUser> searchResults;
  final Function(String userEmail, String displayName) onRequest;
  final String searchText;
  final bool isLoading;
  final bool isAmbiguousUsername;

  const SearchResultList({
    super.key,
    required this.searchResults,
    required this.onRequest,
    required this.searchText,
    required this.isLoading,
    this.isAmbiguousUsername = false,
  });

  @override
  Widget build(BuildContext context) {
    if (searchText.isEmpty) {
      return Container();
    }

    Widget title = ListTile(
      enabled: false,
      minTileHeight: 1,
      title: Padding(
        padding: EdgeInsetsGeometry.only(top: 10),
        child: Text(
          AppLocalizations.of(context)!.addFriendshipSearchResult,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );

    if (isLoading) {
      return Column(children: [
        title,
        ShimmerCardList(height: 50, listEntryLength: 3),
      ]);
    }

    List<Widget> widgets = List.empty(growable: true);

    if (isAmbiguousUsername) {
      widgets.add(ListTile(
          title: Text(AppLocalizations.of(context)!.addFriendshipAmbiguousUsername)));
    } else if (searchResults.isEmpty) {
      widgets.add(ListTile(
          title: Text(AppLocalizations.of(context)!.addFriendshipNoResult)));
    } else {
      widgets.addAll(
        searchResults.map(
          (user) {
            return ListTile(
              leading: UserAvatar(displayName: user.displayName, radius: 18),
              title: Text(user.displayName),
              subtitle: Text(user.fullUsername),
              trailing: FilledButton(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_outlined),
                    const SizedBox(width: 5),
                    Text(AppLocalizations.of(context)!.add),
                  ],
                ),
                onPressed: () => onRequest(user.email, user.displayName),
              ),
            );
          },
        ),
      );
    }

    return Column(children: [title, CardColumn(children: widgets)]);
  }
}
