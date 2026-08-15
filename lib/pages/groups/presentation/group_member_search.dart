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
import '../../../widgets/restyle/primary_button.dart';
import '../../friends/provider/friendship_list.dart';
import '../../users/user_model.dart';
import '../data/group_member_model.dart';
import '../data/group_model.dart';
import '../data/member_removal.dart';

/// Widget that wraps a SearchAnchor for adding/removing group members.
///
/// Renders the current member list inline and opens a search view
/// for finding friends/users/guests to add.
class GroupMemberSearch extends ConsumerStatefulWidget {
  const GroupMemberSearch({
    super.key,
    required this.field,
    this.group,
    this.removeMemberOverride,
  });

  final FormFieldState<dynamic> field;

  /// The group being edited, or null while creating one. Supplies the removal
  /// target's id, the currency the block message names its amount in, and the
  /// removed members the "Removed members" section offers back.
  final Group? group;

  /// Test seam for [GroupRepository.removeMember] — same pattern as
  /// `ClaimPage.sendNotificationOverride`.
  final Future<MemberRemovalOutcome> Function(String groupId, String email)?
  removeMemberOverride;

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

  /// Members soft-removed in this session. `widget.group` is the roster as it was
  /// loaded, so it does not know about them until the next fetch.
  final Set<String> _softRemovedEmails = {};

  /// Members hard-removed in this session: gone entirely, so they must not show
  /// up in the "Removed members" section either.
  final Set<String> _hardRemovedEmails = {};

  @override
  void dispose() {
    _searchAnchorController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  /// The single removal entry point. For an existing group it goes through
  /// [GroupRepository.removeMember], which decides block / soft / hard before
  /// writing anything. While *creating* a group nothing is persisted yet, so the
  /// row is simply dropped from the form value.
  Future<void> _handleRemoveTap(Map<String, dynamic> member) async {
    final l10n = AppLocalizations.of(context)!;
    final email = (member['email'] as String?) ?? '';
    final name = (member['display_name'] as String?) ?? email;
    if (email.isEmpty) return;

    final confirmed = await _confirmRemoval(name);
    if (confirmed != true || !mounted) return;

    final groupId = widget.group?.id;
    if (groupId == null) {
      _dropFromForm(email);
      return;
    }

    final remove = widget.removeMemberOverride ?? GroupRepository.removeMember;

    MemberRemovalOutcome outcome;
    try {
      outcome = await remove(groupId, email);
    } catch (e) {
      debugPrint('Failed to remove $email from group $groupId: $e');
      if (!mounted) return;
      showSnackBar(context, l10n.groupMemberRemoveError(name));
      return;
    }
    if (!mounted) return;

    switch (outcome) {
      case MemberRemovalBlocked(outstanding: final outstanding):
        await _showBlockedDialog(
          name,
          l10n.toCurrency(
            outstanding,
            widget.group?.currencyCode ?? kDefaultCurrencyCode,
          ),
        );
      case MemberRemovalSoftRemoved():
        setState(() => _softRemovedEmails.add(email));
        _dropFromForm(email);
        showSnackBar(context, l10n.groupMemberRemoveSuccess(name));
      case MemberRemovalHardRemoved():
        setState(() => _hardRemovedEmails.add(email));
        _dropFromForm(email);
        showSnackBar(context, l10n.groupMemberRemoveSuccess(name));
    }
  }

  void _dropFromForm(String email) {
    final nbs = GroupRepository.decodeGroupMembersString(widget.field.value);
    nbs.removeWhere((m) => m['email'] == email);
    widget.field.didChange(jsonEncode(nbs));
    _searchQueryNotifier.value = jsonEncode(nbs);
  }

  /// Puts a removed member back into the submitted roster. The save path clears
  /// their `removed_at`, leaving their historical shares untouched.
  void _reAddMember(GroupMember member) {
    setState(() {
      _softRemovedEmails.remove(member.email);
    });
    _addMember({
      'email': member.email,
      'display_name': member.displayName,
      'username': member.username,
      'username_code': member.usernameCode,
      'is_guest': member.isGuest,
    });
  }

  /// Removed members not currently back in the submitted roster. Soft removals
  /// made in this session are included; hard removals never are.
  List<GroupMember> get _removedMembers {
    final group = widget.group;
    if (group == null) return const [];
    final submitted = GroupRepository.decodeGroupMembersString(
      widget.field.value,
    ).map((m) => (m['email'] as String?) ?? '').toSet();
    return group.groupMembers
        .where(
          (m) =>
              (m.isRemoved || _softRemovedEmails.contains(m.email)) &&
              !_hardRemovedEmails.contains(m.email) &&
              !submitted.contains(m.email),
        )
        .toList();
  }

  Future<bool?> _confirmRemoval(String name) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.groupMemberRemoveTitle(name)),
          content: Text(l10n.groupMemberRemoveBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            PrimaryButton(
              compact: true,
              background: Theme.of(dialogContext).colorScheme.error,
              foreground: Theme.of(dialogContext).colorScheme.onError,
              label: l10n.groupMemberRemoveConfirm,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );
  }

  /// The block reason, naming the outstanding amount in the group's currency. A
  /// dialog rather than a snackbar: nothing was written, and the user has to
  /// settle up before this action is available at all.
  Future<void> _showBlockedDialog(String name, String amount) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          content: Text(l10n.groupMemberRemoveBlocked(name, amount)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
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
          onPressed: () => _handleRemoveTap(user),
        );
      }

      if (user['is_guest'] ?? false) {
        subtitleText = AppLocalizations.of(context)!.groupMemberIsGuest;
      }

      return CardListTile(
        isTop: index == 0,
        isBottom: index == groupMembersLength - 1,
        child: ListTile(
          leading: UserAvatar(
            displayName: user["display_name"] ?? "",
            radius: 18,
          ),
          title: Text(titleText),
          subtitle: Text(subtitleText),
          trailing: iconButton,
        ),
      );
    });
  }

  Future<Iterable<Widget>> _buildSuggestions(
    SearchController controller,
  ) async {
    final String input = controller.value.text.trim();
    List<dynamic> nbs = GroupRepository.decodeGroupMembersString(
      widget.field.value,
    );

    final selectedUsers = excludedCandidateEmails(
      submittedMembers: List<Map<String, dynamic>>.from(nbs),
      currentUserEmail: supabase.auth.currentUser?.email,
      allMembers: widget.group?.groupMembers ?? const [],
    );

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Fetch friends
    List<SupaUser> friends = await FriendshipRepository.fetchFriends(
      input,
      selectedUsers,
      99,
    );

    // Fetch other users by exact email/username match (excluding friends and selected)
    List<String> excludeEmails = [
      ...selectedUsers,
      ...friends.map((f) => f.email),
    ];
    List<SupaUser> otherUsers = input.isNotEmpty
        ? await UserRepository.fetchData(input, excludeEmails, 20)
        : [];

    final List<Widget> tiles = [];

    // Friends section
    if (friends.isNotEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Text(l10n.groupMemberSectionFriends, style: labelStyle),
        ),
      );

      tiles.addAll(
        friends.mapIndexed((index, user) {
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
        }),
      );
    }

    // Other users section
    if (otherUsers.isNotEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
          child: Text(l10n.groupMemberSectionOtherUsers, style: labelStyle),
        ),
      );

      tiles.addAll(
        otherUsers.mapIndexed((index, user) {
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
        }),
      );
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
        final Set<String> selectedEmails = excludedCandidateEmails(
          submittedMembers: groupMembers,
          currentUserEmail: currentEmail,
          allMembers: widget.group?.groupMembers ?? const [],
        );

        List<Widget> listTiles = [];

        // You (Owner) row always first.
        listTiles.add(
          ListTile(
            leading: UserAvatar(displayName: l10n.you, radius: 18),
            title: Text(l10n.you),
            trailing: Text(
              l10n.groupMemberOwnerTag,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );

        // Already-selected members (excluding You) with a remove action.
        for (final groupMember in groupMembers) {
          if (groupMember['email'] == currentEmail) continue;

          String subtitleText = fullUsernameFromJson(groupMember);
          if (groupMember['is_guest'] ?? false) {
            subtitleText = l10n.groupMemberIsGuest;
          }

          listTiles.add(
            ListTile(
              leading: UserAvatar(
                displayName: groupMember['display_name'] ?? '',
                radius: 18,
              ),
              title: Text('${groupMember['display_name']}'),
              subtitle: Text(subtitleText),
              trailing: IconButton(
                icon: Icon(Icons.check_circle, color: colorScheme.primary),
                onPressed: () => _handleRemoveTap(groupMember),
              ),
            ),
          );
        }

        // Inline recent/top-N friends as greyed toggle rows (F71 HYBRID). Sourced
        // from the already-loaded friends provider — no new query. The long tail
        // stays behind the "Add friends" SearchAnchor below.
        final friends =
            ref.watch(friendshipListProvider).value?.acceptedFriends ??
            const [];
        final candidates = friends
            .map((f) => f.user)
            .where((u) => !selectedEmails.contains(u.email))
            .take(_inlineFriendLimit)
            .toList();

        for (final user in candidates) {
          listTiles.add(
            Opacity(
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
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _addMember(user.toJson()),
                ),
                onTap: () => _addMember(user.toJson()),
              ),
            ),
          );
        }

        listTiles.add(
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(l10n.groupMemberAddFriends),
            onTap: () => controller.openView(),
          ),
        );

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
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.groupMemberAddGuestLink,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
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
              if (_removedMembers.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionLabel(l10n.groupMemberRemovedSectionTitle),
                const SizedBox(height: 8),
                CardColumn(
                  children: [
                    for (final removed in _removedMembers)
                      Opacity(
                        opacity: 0.45,
                        child: ListTile(
                          leading: UserAvatar(
                            displayName: removed.displayName,
                            radius: 18,
                          ),
                          title: Text(removed.displayName),
                          subtitle: Text(l10n.groupMemberRemovedSectionTitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add_alt_1),
                            tooltip: l10n.groupMemberReAdd,
                            onPressed: () => _reAddMember(removed),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
