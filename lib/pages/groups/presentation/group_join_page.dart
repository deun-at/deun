import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The join write, as an injectable function. Signature-compatible with
/// [GroupRepository.joinGroup], which production passes.
typedef GroupJoiner =
    Future<void> Function(String groupId, {String? guestEmail});

/// The join page's read, as an injectable function. Signature-compatible with
/// [GroupRepository.fetchJoinState].
typedef GroupJoinStateLoader = Future<GroupJoinState> Function(String groupId);

/// The joined group's load before the hand-off. Signature-compatible with
/// [GroupRepository.fetchDetail].
typedef GroupDetailLoader = Future<Group> Function(String groupId);

class GroupJoinPage extends StatefulWidget {
  const GroupJoinPage({
    super.key,
    required this.groupId,
    this.groupName,
    this.joinGroup,
    this.loadJoinState,
    this.loadGroup,
  });

  final String groupId;
  final String? groupName;

  /// Test seam for the join write. Null in production → [GroupRepository.joinGroup].
  final GroupJoiner? joinGroup;

  /// Test seam for the join-state read. Null in production →
  /// [GroupRepository.fetchJoinState].
  final GroupJoinStateLoader? loadJoinState;

  /// Test seam for the hand-off's group load. Null in production →
  /// [GroupRepository.fetchDetail].
  final GroupDetailLoader? loadGroup;

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  bool _loading = true;
  bool _joining = false;
  List<GroupMember> _guestMembers = const [];
  String? _selectedGuestEmail; // null = join as new member

  @override
  void initState() {
    super.initState();
    _loadJoinState();
  }

  Future<void> _loadJoinState() async {
    try {
      final state =
          await (widget.loadJoinState ?? GroupRepository.fetchJoinState)(
            widget.groupId,
          );
      if (!mounted) return;
      if (state.isActiveMember) {
        await _openGroup();
        return;
      }
      setState(() {
        _guestMembers = state.joinableGuests;
        _loading = false;
      });
    } catch (e) {
      // As before: no guests, page stays, joining as a new member still works.
      if (mounted) {
        setState(() {
          _guestMembers = const [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _openGroup() async {
    final g = await (widget.loadGroup ?? GroupRepository.fetchDetail)(
      widget.groupId,
    );
    if (!mounted) return;
    GoRouter.of(context).go('/group/details', extra: {'group': g});
  }

  Future<void> _joinGroup() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await (widget.joinGroup ?? GroupRepository.joinGroup)(
        widget.groupId,
        guestEmail: _selectedGuestEmail,
      );
      await _openGroup();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          DeunHeader(title: t.groupInviteJoinTitle),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.groupName ?? 'Group',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.groupInviteJoinSubtitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Guest selection section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.groupInviteGuestSelectTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.groupInviteGuestSelectSubtitle,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      else
                        RadioGroup<String?>(
                          groupValue: _selectedGuestEmail,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedGuestEmail = value;
                            });
                          },
                          child: Column(
                            children: [
                              RadioListTile<String?>(
                                title: Text(t.groupInviteJoinAsNew),
                                value: null,
                              ),
                              if (_guestMembers.isEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    t.groupInviteNoGuestsFound,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                )
                              else
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _guestMembers.length,
                                    itemBuilder: (context, index) {
                                      final gm = _guestMembers[index];
                                      return RadioListTile<String?>(
                                        title: Text(gm.displayName),
                                        subtitle: Text(t.groupMemberIsGuest),
                                        value: gm.email,
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        fullWidth: false,
                        loading: _joining,
                        icon: Icons.login,
                        onPressed: _joining ? null : _joinGroup,
                        label: t.groupInviteTransferButton,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
