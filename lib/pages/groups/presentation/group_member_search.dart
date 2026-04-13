import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../main.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/search_view.dart';
import '../../users/user_model.dart';

/// Widget that wraps a SearchAnchor for adding/removing group members.
///
/// Renders the current member list inline and opens a search view
/// for finding friends/users/guests to add.
class GroupMemberSearch extends StatefulWidget {
  const GroupMemberSearch({
    super.key,
    required this.field,
  });

  final FormFieldState<dynamic> field;

  @override
  State<GroupMemberSearch> createState() => _GroupMemberSearchState();
}

class _GroupMemberSearchState extends State<GroupMemberSearch> {
  final SearchController _searchAnchorController = SearchController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  @override
  void dispose() {
    _searchAnchorController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Iterable<Widget> _buildMemberSelection(SearchController controller) {
    List<Map<String, dynamic>> groupMembers =
        GroupRepository.decodeGroupMembersString(widget.field.value);
    int groupMembersLength = groupMembers.length;

    return groupMembers.mapIndexed((index, user) {
      String titleText = "";
      String subtitleText = fullUsernameFromJson(user);
      Widget iconButton;

      if (user['email'] == supabase.auth.currentUser?.email) {
        titleText = AppLocalizations.of(context)!.you;
        iconButton = IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {},
        );
      } else {
        titleText = "${user["display_name"]}";
        iconButton = IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          icon: const Icon(Icons.delete),
          onPressed: () {
            groupMembers.removeAt(index);
            widget.field.didChange(jsonEncode(groupMembers));
            _searchQueryNotifier.value = jsonEncode(groupMembers);
          },
        );
      }

      if (user['is_guest'] ?? false) {
        subtitleText = AppLocalizations.of(context)!.groupMemberIsGuest;
      }

      return CardListTile(
        isTop: index == 0,
        isBottom: index == groupMembersLength - 1,
        child: ListTile(
          leading: UserAvatar(displayName: user["display_name"] ?? "", radius: 18),
          title: Text(titleText),
          subtitle: Text(subtitleText),
          trailing: iconButton,
        ),
      );
    });
  }

  Future<Iterable<Widget>> _buildSuggestions(SearchController controller) async {
    final String input = controller.value.text.trim();
    List<dynamic> nbs = GroupRepository.decodeGroupMembersString(widget.field.value);

    List<String> selectedUsers = nbs.map((element) => element['email'] as String).toList();
    selectedUsers.add(supabase.auth.currentUser?.email ?? '');

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Fetch friends
    List<SupaUser> friends = await FriendshipRepository.fetchFriends(input, selectedUsers, 99);

    // Fetch other users by exact email/username match (excluding friends and selected)
    List<String> excludeEmails = [...selectedUsers, ...friends.map((f) => f.email)];
    List<SupaUser> otherUsers =
        input.isNotEmpty ? await UserRepository.fetchData(input, excludeEmails, 20) : [];

    final List<Widget> tiles = [];

    // Friends section
    if (friends.isNotEmpty) {
      tiles.add(Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
        child: Text(
          l10n.groupMemberSectionFriends,
          style: labelStyle,
        ),
      ));

      tiles.addAll(friends.mapIndexed((index, user) {
        return CardListTile(
          isTop: index == 0,
          isBottom: index == friends.length - 1,
          child: ListTile(
            leading: UserAvatar(displayName: user.displayName, radius: 18),
            title: Text(user.displayName),
            subtitle: Text(user.fullUsername),
            onTap: () {
              nbs.add(user.toJson());
              widget.field.didChange(jsonEncode(nbs));
              controller.text = "";
            },
          ),
        );
      }));
    }

    // Other users section
    if (otherUsers.isNotEmpty) {
      tiles.add(Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
        child: Text(
          l10n.groupMemberSectionOtherUsers,
          style: labelStyle,
        ),
      ));

      tiles.addAll(otherUsers.mapIndexed((index, user) {
        return CardListTile(
          isTop: index == 0,
          isBottom: index == otherUsers.length - 1,
          child: ListTile(
            leading: UserAvatar(displayName: user.displayName, radius: 18),
            title: Text(user.displayName),
            subtitle: Text(user.fullUsername),
            onTap: () {
              nbs.add(user.toJson());
              widget.field.didChange(jsonEncode(nbs));
              controller.text = "";
            },
          ),
        );
      }));
    }

    // Empty state
    if (friends.isEmpty && otherUsers.isEmpty && input.isEmpty) {
      tiles.add(
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(title: Text(l10n.groupMemberResultEmpty)),
        ),
      );
    }

    // Add as guest option
    if (input.isNotEmpty) {
      tiles.add(const SizedBox(height: 12));
      tiles.add(
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(l10n.groupMemberAddGuestOption(input)),
            subtitle: Text(l10n.groupMemberAddGuestSubtitle),
            onTap: () {
              final ts = DateTime.now().microsecondsSinceEpoch;
              final tempEmail = 'guest+$ts@pending.invalid';
              nbs.add({
                'email': tempEmail,
                'display_name': input,
                'is_guest': true,
                'is_guest_pending': true,
              });
              widget.field.didChange(jsonEncode(nbs));
              controller.text = "";
            },
          ),
        ),
      );
    }

    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchAnchorController,
      viewHintText: AppLocalizations.of(context)!.groupMemberSelectionEmpty,
      viewLeading: IconButton(
        icon: Icon(Icons.check),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      builder: (context, controller) {
        List<Map<String, dynamic>> groupMembers =
            GroupRepository.decodeGroupMembersString(widget.field.value);

        List<Widget> listTiles = [];

        if (groupMembers.isNotEmpty &&
            !(groupMembers.length == 1 && groupMembers.first['email'] == supabase.auth.currentUser?.email)) {
          listTiles.addAll(groupMembers.map((groupMember) {
            String displayName = groupMember["display_name"];
            String subtitleText = fullUsernameFromJson(groupMember);

            if (groupMember["email"] == supabase.auth.currentUser?.email) {
              displayName = AppLocalizations.of(context)!.you;
            }

            if (groupMember['is_guest'] ?? false) {
              subtitleText = AppLocalizations.of(context)!.groupMemberIsGuest;
            }

            return ListTile(
              leading: UserAvatar(displayName: groupMember["display_name"] ?? "", radius: 18),
              title: Text(displayName),
              subtitle: Text(subtitleText),
              onTap: () {
                controller.openView();
              },
            );
          }));
        }

        listTiles.add(ListTile(
          leading: const Icon(Icons.person_add),
          title: Text(AppLocalizations.of(context)!.groupMemberAddFriends),
        ));

        return CardColumn(children: listTiles);
      },
      suggestionsBuilder: (context, controller) {
        if (controller.text.isEmpty) {
          return _buildMemberSelection(controller);
        }
        return _buildSuggestions(controller);
      },
      viewBuilder: (suggestions) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 10, left: 16),
              child: Text(
                _searchAnchorController.text.isEmpty
                    ? AppLocalizations.of(context)!.groupMemberSelectionTitle
                    : AppLocalizations.of(context)!.groupMemberSelectionEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: SearchView(
                searchQueryNotifier: _searchQueryNotifier,
                suggestions: suggestions,
              ),
            ),
          ],
        );
      },
    );
  }
}
