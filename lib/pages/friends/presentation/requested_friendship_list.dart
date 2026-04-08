import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/card_list_view_builder.dart';

class RequestedFriendshipList extends StatelessWidget {
  final List<SupaUser> requestedFriendships;
  final Function(String userEmail, String displayName) onCancel;
  final bool isLoading;

  const RequestedFriendshipList({
    super.key,
    required this.requestedFriendships,
    required this.onCancel,
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
          AppLocalizations.of(context)!.addFriendshipRequested,
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

    if (requestedFriendships.isEmpty) {
      widgets.add(ListTile(
          title:
              Text(AppLocalizations.of(context)!.addFriendshipRequestedNoResult)));
    } else {
      widgets.addAll(
        requestedFriendships.map(
          (user) {
            return ListTile(
              title: Text(user.displayName),
              subtitle: Text(user.fullUsername),
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

    return Column(children: [title, CardColumn(children: widgets)]);
  }
}
