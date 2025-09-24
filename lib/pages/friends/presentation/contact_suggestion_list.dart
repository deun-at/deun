import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

class ContactSuggestionList extends StatelessWidget {
  final Future<List<SupaUser>> userContactFuture;
  final Function(String userEmail, String displayName) onRequest;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const ContactSuggestionList({
    super.key,
    required this.userContactFuture,
    required this.onRequest,
    required this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupaUser>>(
      future: userContactFuture,
      builder: (context, snapshot) {
        Widget widget;
        List<Widget> widgets = List.empty(growable: true);

        Widget title = ListTile(
          enabled: false,
          minTileHeight: 1,
          title: Padding(
            padding: EdgeInsetsGeometry.only(top: 10),
            child: Text(
              AppLocalizations.of(context)!.addFriendshipAllContacts,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          widget = ShimmerCardList(
            height: 50,
            listEntryLength: 3,
          );
        } else {
          if (snapshot.hasError) {
            widgets.add(
                ListTile(title: Text(AppLocalizations.of(context)!.errorLoadingData)));
          } else if (snapshot.data == null || snapshot.data!.isEmpty) {
            widgets.add(ListTile(
                title: Text(AppLocalizations.of(context)!.addFriendshipContactNoResult),
                subtitle: Text(AppLocalizations.of(context)!
                    .addFriendshipContactPermissionSubtitle)));
          } else {
            widgets.addAll(
              snapshot.data!.map(
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
