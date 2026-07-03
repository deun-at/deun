import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/user_avatar.dart';

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
        padding: const EdgeInsetsGeometry.only(top: 10),
        child: Text(
          AppLocalizations.of(context)!.addFriendshipRequested,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );

    if (isLoading) {
      return Column(children: [
        title,
        const ShimmerCardList(
          height: 50,
          listEntryLength: 3,
          shape: ShimmerShape.row,
        ),
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
              leading: UserAvatar(displayName: user.displayName, radius: 18),
              title: Text(user.displayName),
              subtitle: Text(user.fullUsername),
              trailing: PrimaryButton(
                label: AppLocalizations.of(context)!.cancel,
                icon: Icons.person_add_disabled,
                background: Theme.of(context).colorScheme.error,
                foreground: Theme.of(context).colorScheme.onError,
                onPressed: () => onCancel(user.email, user.displayName),
                compact: true,
              ),
            );
          },
        ),
      );
    }

    return Column(children: [title, CardColumn(children: widgets)]);
  }
}
