import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../main.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/search_view.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../friends/provider/friendship_list.dart';
import '../../users/user_model.dart';

/// Widget that wraps a SearchAnchor for adding/removing group members.
///
/// Renders the current member list inline and opens a search view
/// for finding friends/users/guests to add.
class GroupMemberSearch extends ConsumerStatefulWidget {
  const GroupMemberSearch({
    super.key,
    required this.field,
  });

  final FormFieldState<dynamic> field;

  @override
  ConsumerState<GroupMemberSearch> createState() => _GroupMemberSearchState();
}

class _GroupMemberSearchState extends ConsumerState<GroupMemberSearch> {
  /// How many top/recent friends to surface inline as toggle rows (F71). The v3
  /// mockup roster is a 5-friend demo prop; the SearchAnchor stays for the long
  /// tail (r8 = HYBRID). ponytail: fixed N, reads first N from the already-loaded
  /// friends provider — no extra query.
  static const int _inlineFriendLimit = 5;
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

  /// Reuse the SAME add path the SearchAnchor suggestions use: append the
  /// user's JSON to the member list and push it into the form field.
  void _addMember(Map<String, dynamic> user) {
    final nbs = GroupRepository.decodeGroupMembersString(widget.field.value);
    nbs.add(user);
    widget.field.didChange(jsonEncode(nbs));
    _searchQueryNotifier.value = jsonEncode(nbs);
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchAnchorController,
      viewHintText: AppLocalizations.of(context)!.groupMemberSelectionEmpty,
      viewLeading: IconButton(
        icon: const Icon(Icons.check),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      builder: (context, controller) {
        final l10n = AppLocalizations.of(context)!;
        final colorScheme = Theme.of(context).colorScheme;
        final currentEmail = supabase.auth.currentUser?.email;

        List<Map<String, dynamic>> groupMembers =
            GroupRepository.decodeGroupMembersString(widget.field.value);
        final Set<String> selectedEmails =
            groupMembers.map((m) => m['email'] as String? ?? '').toSet()..add(currentEmail ?? '');

        List<Widget> listTiles = [];

        // You (Owner) row always first.
        listTiles.add(ListTile(
          leading: UserAvatar(displayName: l10n.you, radius: 18),
          title: Text(l10n.you),
          trailing: Text(
            l10n.groupMemberOwnerTag,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ));

        // Already-selected members (excluding You) with a remove action.
        for (final groupMember in groupMembers) {
          if (groupMember['email'] == currentEmail) continue;

          String subtitleText = fullUsernameFromJson(groupMember);
          if (groupMember['is_guest'] ?? false) {
            subtitleText = l10n.groupMemberIsGuest;
          }

          listTiles.add(ListTile(
            leading: UserAvatar(displayName: groupMember['display_name'] ?? '', radius: 18),
            title: Text('${groupMember['display_name']}'),
            subtitle: Text(subtitleText),
            trailing: IconButton(
              icon: Icon(Icons.check_circle, color: colorScheme.primary),
              onPressed: () {
                final nbs = GroupRepository.decodeGroupMembersString(widget.field.value);
                nbs.removeWhere((m) => m['email'] == groupMember['email']);
                widget.field.didChange(jsonEncode(nbs));
                _searchQueryNotifier.value = jsonEncode(nbs);
              },
            ),
          ));
        }

        // Inline recent/top-N friends as greyed toggle rows (F71 HYBRID). Sourced
        // from the already-loaded friends provider — no new query. The long tail
        // stays behind the "Add friends" SearchAnchor below.
        final friends = ref.watch(friendshipListProvider).value?.acceptedFriends ?? const [];
        final candidates = friends
            .map((f) => f.user)
            .where((u) => !selectedEmails.contains(u.email))
            .take(_inlineFriendLimit)
            .toList();

        for (final user in candidates) {
          listTiles.add(Opacity(
            opacity: 0.45,
            child: ListTile(
              leading: UserAvatar(displayName: user.displayName, radius: 18),
              title: Text(user.displayName),
              subtitle: Text(user.fullUsername),
              // Wrapped in an IconButton (like the selected-member check row)
              // so both trailing icons share the same footprint and line up —
              // a bare Icon sat flush-right and read as misaligned. The whole
              // row stays tappable via onTap below.
              trailing: IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: colorScheme.onSurfaceVariant),
                onPressed: () => _addMember(user.toJson()),
              ),
              onTap: () => _addMember(user.toJson()),
            ),
          ));
        }

        listTiles.add(ListTile(
          leading: const Icon(Icons.person_add),
          title: Text(l10n.groupMemberAddFriends),
          onTap: () => controller.openView(),
        ));

        // F156: zero the inherited horizontal Card margin (theme default is
        // 10px) so this members block sits flush at the edit form's 20px
        // ListView padding, matching its SoftCard siblings. Scoped here via a
        // local Theme override — the global cardTheme and shared CardColumn are
        // untouched (other consumers still get the 10px margin).
        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: Theme.of(context).cardTheme.copyWith(
                  margin: const EdgeInsets.symmetric(vertical: 1),
                ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header with the "Add guest" link (F71 / F135). Tapping it
              // opens the SearchAnchor view where guest-add already lives.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionLabel(
                  l10n.groupMemberSectionTitle,
                  trailing: InkWell(
                    onTap: () => controller.openView(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            l10n.groupMemberAddGuestLink,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              CardColumn(children: listTiles),
            ],
          ),
        );
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
              padding: const EdgeInsets.only(top: 10, left: 16),
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
