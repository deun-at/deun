import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/member_add.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/search_field.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The standalone member-management surface (group-member-add-flow): a page
/// (not a sheet) reachable from group detail and from the group-edit form,
/// carrying every add path (friend, email/handle lookup, guest) and the
/// existing removal flow. Membership writes happen ONE AT A TIME, immediately
/// — there is no save button and no batch commit.
class GroupMembersPage extends ConsumerStatefulWidget {
  const GroupMembersPage({
    super.key,
    required this.group,
    this.searchOverride,
    this.addMemberOverride,
    this.createGuestOverride,
    this.previewRemovalOverride,
    this.removeMemberOverride,
    this.notifyOverride,
  });

  final Group group;

  /// Test seams — same shape as `GroupEdit.saveOverride` and
  /// `ClaimPage.sendNotificationOverride`. Null uses the real path.
  final Future<MemberSearchResults> Function(String query, Set<String> exclude)?
  searchOverride;
  final Future<MemberAddOutcome> Function(String groupId, String email)?
  addMemberOverride;
  final Future<SupaUser> Function(String displayName)? createGuestOverride;
  final Future<MemberRemovalOutcome> Function(
    String groupId,
    String email, {
    required Currency currency,
  })?
  previewRemovalOverride;
  final Future<MemberRemovalOutcome> Function(
    String groupId,
    String email, {
    required Currency currency,
  })?
  removeMemberOverride;
  final void Function(String groupId, Set<String> emails)? notifyOverride;

  @override
  ConsumerState<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends ConsumerState<GroupMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _guestNameController = TextEditingController();
  Timer? _debounce;

  /// Sequence token: a slow search for an older query must never repaint over
  /// a newer one (same idea as `GroupMemberSearch._suggestionSeq`).
  int _searchSeq = 0;

  String _query = '';
  MemberSearchResults? _results;
  bool _searching = false;
  bool _ambiguous = false;

  /// Non-null = the guest name-entry step is open, carrying the query it was
  /// opened from.
  String? _guestDraftName;

  /// One write (add / remove / guest-create) at a time.
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  Group _currentGroup() =>
      ref.read(groupDetailProvider(widget.group.id)).value ?? widget.group;

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    final group = _currentGroup();
    final exclude = addCandidateExclusions(
      members: group.groupMembers,
      currentUserEmail: supabase.auth.currentUser?.email,
    );
    setState(() => _searching = true);
    try {
      final results = await (widget.searchOverride ?? _fetchCandidates)(
        query,
        exclude,
      );
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _results = results;
        _ambiguous = false;
        _searching = false;
      });
    } on AmbiguousUsernameException {
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _results = null;
        _ambiguous = true;
        _searching = false;
      });
    }
  }

  /// The lookup carried over from `GroupMemberSearch._buildSuggestions`,
  /// unchanged except that it now returns instead of building tiles.
  Future<MemberSearchResults> _fetchCandidates(
    String query,
    Set<String> exclude,
  ) async {
    final friends = await FriendshipRepository.fetchFriends(query, exclude, 99);
    final others = query.isEmpty
        ? const <SupaUser>[]
        : await UserRepository.fetchData(query, [
            ...exclude,
            ...friends.map((f) => f.email),
          ], 20);
    return MemberSearchResults(friends: friends, otherUsers: others);
  }

  void _notify(String groupId, Set<String> emails) {
    sendGroupNotification(context, groupId, emails);
  }

  /// Each add persists on its own; no batch, no commit button. No success
  /// snackbar in any branch: the member appearing in the roster is the
  /// confirmation. The page stays open and the field is cleared for the next
  /// add.
  Future<void> _handleAdd({
    required String email,
    required String name,
    required bool isGuest,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final group = _currentGroup();
    try {
      MemberAddOutcome outcome;
      try {
        outcome = await (widget.addMemberOverride ?? GroupRepository.addMember)(
          group.id,
          email,
        );
      } catch (e) {
        debugPrint('Failed to add $email to group ${group.id}: $e');
        if (mounted) showSnackBar(context, l10n.groupMemberAddError(name));
        return;
      }
      if (!mounted) return;

      if (outcome == MemberAddOutcome.alreadyMember) {
        showSnackBar(context, l10n.groupMemberAlreadyInGroup(name));
      } else if (shouldNotifyAddedMember(outcome: outcome, isGuest: isGuest)) {
        (widget.notifyOverride ?? _notify)(group.id, {email});
      }

      _searchController.clear();
      setState(() {
        _query = '';
        _results = null;
        _guestDraftName = null;
      });
      await ref
          .read(groupDetailProvider(widget.group.id).notifier)
          .reload(group.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGuest() async {
    final name = _guestNameController.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final guest =
          await (widget.createGuestOverride ?? UserRepository.createGuest)(
            name,
          );
      setState(() => _busy = false);
      await _handleAdd(
        email: guest.email,
        name: guest.displayName,
        isGuest: true,
      );
    } catch (e) {
      debugPrint('Failed to create guest "$name": $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showSnackBar(context, l10n.groupMemberGuestCreateError(name));
      // The step STAYS open with the name in the field — nothing is dropped.
    }
  }

  Future<bool?> _confirmSoftRemoval(String name) {
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

  /// Outcome before write, no confirmation invented. On success: no snackbar —
  /// the roster is the receipt.
  Future<void> _handleRemove(GroupMember member) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final group = _currentGroup();
    final name = member.displayName;
    try {
      final outcome =
          await (widget.previewRemovalOverride ??
              GroupRepository.previewMemberRemoval)(
            group.id,
            member.email,
            currency: group.currency,
          );

      switch (outcome) {
        case MemberRemovalBlocked():
          // Write nothing, show NO dialog: the balance moved since the page
          // loaded, so a reload repaints the row carrying it and the remove
          // affordance disappears on its own.
          await ref
              .read(groupDetailProvider(widget.group.id).notifier)
              .reload(group.id);
          return;
        case MemberRemovalSoftRemoved():
          final confirmed = await _confirmSoftRemoval(name);
          if (confirmed != true || !mounted) return;
        case MemberRemovalHardRemoved():
        // No dialog at all — straight through.
      }

      await (widget.removeMemberOverride ?? GroupRepository.removeMember)(
        group.id,
        member.email,
        currency: group.currency,
      );
      if (!mounted) return;
      await ref
          .read(groupDetailProvider(widget.group.id).notifier)
          .reload(group.id);
    } catch (e) {
      debugPrint('Failed to remove ${member.email} from group ${group.id}: $e');
      if (mounted) showSnackBar(context, l10n.groupMemberRemoveError(name));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          body: Column(
            children: [
              DeunHeader(title: l10n.groupMemberSectionTitle),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Outside the provider-watched subtree, so a roster
                      // rebuild never dismisses the keyboard.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                        child: SearchField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          hintText: l10n.groupMembersSearchHint,
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final group =
                                ref
                                    .watch(groupDetailProvider(widget.group.id))
                                    .value ??
                                widget.group;

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                              children: [
                                if (_guestDraftName != null)
                                  _buildGuestStep(context)
                                else if (_query.isNotEmpty)
                                  ..._buildResultsBlock(context),
                                SectionLabel(l10n.groupMemberSectionTitle),
                                const SizedBox(height: 8),
                                for (final member in group.activeMembers)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildMemberRow(
                                      context,
                                      group,
                                      member,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Preserving all four add paths: friend/contact suggestion, `name#1234`
  /// lookup and email lookup (both fed by [UserRepository.fetchData]), and
  /// create-guest — always last, and only while [_query] is non-empty.
  List<Widget> _buildResultsBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    if (_ambiguous) {
      widgets.add(
        SoftCard(
          child: Text(
            l10n.addFriendshipAmbiguousUsername,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    // A superseded/in-flight search never repaints stale results over a fresh
    // query.
    final results = _searching ? null : _results;

    if (results != null && results.friends.isNotEmpty) {
      widgets.add(SectionLabel(l10n.groupMemberSectionFriends));
      widgets.add(const SizedBox(height: 8));
      for (final friend in results.friends) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CandidateRow(
              user: friend,
              onTap: () => _handleAdd(
                email: friend.email,
                name: friend.displayName,
                isGuest: false,
              ),
            ),
          ),
        );
      }
    }

    if (results != null && results.otherUsers.isNotEmpty) {
      widgets.add(SectionLabel(l10n.groupMemberSectionOtherUsers));
      widgets.add(const SizedBox(height: 8));
      for (final user in results.otherUsers) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CandidateRow(
              user: user,
              onTap: () => _handleAdd(
                email: user.email,
                name: user.displayName,
                isGuest: false,
              ),
            ),
          ),
        );
      }
    }

    widgets.add(
      SoftCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.person_add),
          title: Text(l10n.groupMemberAddGuestOption(_query)),
          subtitle: Text(l10n.groupMemberAddGuestSubtitle),
          onTap: () => setState(() {
            _guestDraftName = _query;
            _guestNameController.text = _query;
          }),
        ),
      ),
    );
    widgets.add(const SizedBox(height: 16));

    return widgets;
  }

  Widget _buildGuestStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          child: AppTextField(
            controller: _guestNameController,
            label: l10n.groupMemberGuestNameLabel,
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: l10n.groupMemberGuestCreateButton,
          loading: _busy,
          onPressed: _createGuest,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _guestDraftName = null),
            child: Text(l10n.cancel),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMemberRow(
    BuildContext context,
    Group group,
    GroupMember member,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentUserEmail = supabase.auth.currentUser?.email;
    final outstanding = group.memberBalances[member.email] ?? 0;

    final Widget trailing;
    if (member.email == currentUserEmail) {
      trailing = const SizedBox.shrink();
    } else if (!isSettled(outstanding, group.currency)) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            outstanding.abs(),
            currency: group.currency,
            semantic: MoneySemantic.neutral,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: l10n.groupDetailSettleUp,
            compact: true,
            onPressed: () => GoRouter.of(
              context,
            ).push('/group/details/payment', extra: {'group': group}),
          ),
        ],
      );
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _handleRemove(member),
      );
    }

    return SoftCard(
      child: Row(
        children: [
          MemberAvatar(
            name: member.displayName,
            colorKey: member.email,
            isYou: member.email == currentUserEmail,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.isGuest
                      ? l10n.groupMemberIsGuest
                      : member.fullUsername,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// A tappable friend/other-user search result row.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.user, required this.onTap});

  final SupaUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          MemberAvatar(name: user.displayName, colorKey: user.email),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.fullUsername,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
