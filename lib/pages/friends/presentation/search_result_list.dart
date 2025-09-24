import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

class SearchResultList extends StatelessWidget {
  final Future<List<SupaUser>> userSearchFuture;
  final Function(String userEmail, String displayName) onRequest;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final String searchText;

  const SearchResultList({
    super.key,
    required this.userSearchFuture,
    required this.onRequest,
    required this.scaffoldMessengerKey,
    required this.searchText,
  });

  @override
  Widget build(BuildContext context) {
    if (searchText.isEmpty) {
      return Container();
    }

    return FutureBuilder<List<SupaUser>>(
      future: userSearchFuture,
      builder: (context, userList) {
        Widget widget;
        List<Widget> widgets = List.empty(growable: true);

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

        if (userList.connectionState == ConnectionState.waiting) {
          widget = ShimmerCardList(
            height: 50,
            listEntryLength: 3,
          );
        } else {
          if (userList.hasError) {
            widgets.add(
                ListTile(title: Text(AppLocalizations.of(context)!.errorLoadingData)));
          } else if (userList.data == null || userList.data?.isEmpty == true) {
            widgets.add(ListTile(
                title: Text(AppLocalizations.of(context)!.addFriendshipNoResult)));
          } else {
            widgets.addAll(
              userList.data!.map(
                (user) {
                  return ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
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
                      onPressed: () =>
                          onRequest(user.email, user.displayName),
                    ),
                  );
                },
              ),
            );
          }

          widget = CardColumn(children: widgets);
        }

        return Column(children: [title, widget]);
      },
    );
  }
}
