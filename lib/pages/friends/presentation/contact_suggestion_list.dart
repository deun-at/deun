import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';

import '../../../widgets/user_avatar.dart';

class ContactSuggestionList extends StatelessWidget {
  final List<SupaUser> contactSuggestions;
  final Function(String userEmail, String displayName) onRequest;
  final bool isLoading;
  final bool contactPermissionDenied;
  final VoidCallback? onRequestPermission;

  const ContactSuggestionList({
    super.key,
    required this.contactSuggestions,
    required this.onRequest,
    required this.isLoading,
    this.contactPermissionDenied = false,
    this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
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

    if (isLoading) {
      return Column(children: [
        title,
        ShimmerCardList(height: 50, listEntryLength: 3),
      ]);
    }

    List<Widget> widgets = List.empty(growable: true);

    if (contactSuggestions.isEmpty) {
      widgets.add(ListTile(
        title: Text(AppLocalizations.of(context)!.addFriendshipContactNoResult),
        subtitle: Text(AppLocalizations.of(context)!
            .addFriendshipContactPermissionSubtitle),
        trailing: contactPermissionDenied && onRequestPermission != null
            ? FilledButton.tonal(
                onPressed: onRequestPermission,
                child: Text(AppLocalizations.of(context)!.addFriendshipContactOpenSettings),
              )
            : null,
      ));
    } else {
      widgets.addAll(
        contactSuggestions.map(
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
