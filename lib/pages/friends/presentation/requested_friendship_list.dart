import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/card_list_view_builder.dart';

class RequestedFriendshipList extends StatelessWidget {
  final Future<List<SupaUser>> userRequestedFuture;
  final Function(String userEmail, String displayName) onCancel;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const RequestedFriendshipList({
    super.key,
    required this.userRequestedFuture,
    required this.onCancel,
    required this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupaUser>>(
      future: userRequestedFuture,
      builder: (context, userList) {
        Widget widget;
        List<Widget> widgets = List.empty(growable: true);

        Widget title = ListTile(
          enabled: false,
          minTileHeight: 1,
          title: Padding(
            padding: EdgeInsetsGeometry.only(top: 10),
            child: Text(
              AppLocalizations.of(context)!.addFriendshipRequested,
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
                title:
                    Text(AppLocalizations.of(context)!.addFriendshipRequestedNoResult)));
          } else {
            widgets.addAll(
              userList.data!.map(
                (user) {
                  return ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: () => onCancel(user.email, user.displayName),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_disabled,
                              color: Theme.of(context).colorScheme.onError),
                          const SizedBox(width: 5),
                          Text(AppLocalizations.of(context)!.cancel),
                        ],
                      ),
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
