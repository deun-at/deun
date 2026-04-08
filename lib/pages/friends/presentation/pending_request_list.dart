import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

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
        padding: EdgeInsetsGeometry.only(top: 10),
        child: Text(
          AppLocalizations.of(context)!.addFriendshipPendingRequests,
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

    if (pendingRequests.isEmpty || pendingRequests.first['email'] == null) {
      widgets.add(ListTile(
          title: Text(AppLocalizations.of(context)!.addFriendshipRequestNoResult)));
    } else {
      widgets.addAll(
        pendingRequests.map(
          (user) {
            return ListTile(
              title: Text(user['display_name']),
              subtitle: Text(fullUsernameFromJson(user)),
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

    return Column(children: [title, CardColumn(children: widgets)]);
  }
}
