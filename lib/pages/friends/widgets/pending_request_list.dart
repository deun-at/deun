import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

class PendingRequestList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> userPendingFuture;
  final Function(String userEmail, String displayName) onAccept;
  final Function(String userEmail, String displayName) onDecline;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const PendingRequestList({
    super.key,
    required this.userPendingFuture,
    required this.onAccept,
    required this.onDecline,
    required this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: userPendingFuture,
      builder: (context, userList) {
        Widget widget;
        List<Widget> widgets = List.empty(growable: true);

        Widget title = ListTile(
          enabled: false,
          minTileHeight: 1,
          title: Padding(
            padding: EdgeInsetsGeometry.only(top: 10),
            child: Text(
              AppLocalizations.of(context)!.addFriendshipPendingRequests,
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
          } else if (userList.data == null ||
              userList.data?.isEmpty == true ||
              userList.data?.first['email'] == null) {
            widgets.add(ListTile(
                title: Text(AppLocalizations.of(context)!.addFriendshipRequestNoResult)));
          } else {
            widgets.addAll(
              userList.data!.map(
                (user) {
                  return ListTile(
                    title: Text(user['display_name']),
                    subtitle: Text(user['email']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: () => onAccept(user['email'], user['display_name']),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_outlined),
                              const SizedBox(width: 5),
                              Text(AppLocalizations.of(context)!.accept),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => onDecline(user['email'], user['display_name']),
                          icon: Icon(Icons.close),
                        ),
                      ],
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
