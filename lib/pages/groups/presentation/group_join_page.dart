import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deun/l10n/app_localizations.dart';

class GroupJoinPage extends StatefulWidget {
  const GroupJoinPage({super.key, required this.groupId, this.groupName});

  final String groupId;
  final String? groupName;

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  bool _loading = true;
  bool _joining = false;
  List<Map<String, dynamic>> _guestMembers = [];
  String? _selectedGuestEmail; // null = join as new member

  Future<void> _checkAlreadyMember() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return;
    try {
      final existing = await supabase
          .from('group_member')
          .select('email')
          .eq('group_id', widget.groupId)
          .eq('email', email)
          .maybeSingle();

      if (existing != null) {
        final g = await Group.fetchDetail(widget.groupId);
        if (!mounted) return;
        GoRouter.of(context).go('/group/details', extra: {'group': g});
      }
    } catch (e) {
      // ignore and keep on page
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAlreadyMember();
    _fetchGuestMembers();
  }

  Future<void> _fetchGuestMembers() async {
    try {
      final data = await supabase
          .from('group_member')
          .select('email, ...user(display_name:display_name, is_guest:is_guest)')
          .eq('group_id', widget.groupId);

      final guests = <Map<String, dynamic>>[];
      for (final row in (data as List<dynamic>)) {
        final isGuest = (row['is_guest'] ?? row['user']?['is_guest']) ?? false;
        final displayName = (row['display_name'] ?? row['user']?['display_name']) ?? row['email'];
        if (isGuest == true) {
          guests.add({'email': row['email'], 'display_name': displayName});
        }
      }
      if (mounted) {
        setState(() {
          _guestMembers = guests;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guestMembers = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return;

    setState(() => _joining = true);
    try {
      // Ensure user is member
      final existing = await supabase
          .from('group_member')
          .select('email')
          .eq('group_id', widget.groupId)
          .eq('email', email)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('group_member').insert({
          'group_id': widget.groupId,
          'email': email,
        });

        // If a guest was selected, transfer their data to current user and remove guest from this group
        if (_selectedGuestEmail != null) {
          final guestEmail = _selectedGuestEmail!;

          // 1) Update expense.paid_by for this group
          await supabase.from('expense').update({'paid_by': email}).eq('paid_by', guestEmail);

          // 2) Update expense_entry_share.email for this email
          await supabase.from('expense_entry_share').update({'email': email}).eq('email', guestEmail);

          // 3) Remove guest membership from this group
          await supabase.from('group_member').delete().eq('group_id', widget.groupId).eq('email', guestEmail);

          // 4) Remove guest member from user
          await supabase.from('user').delete().eq('email', guestEmail);
        }
      }

      // Update calculated shares after changes
      await supabase.rpc('update_group_member_shares', params: {"_group_id": widget.groupId, "_expense_id": null});

      // Navigate to group details
      final g = await Group.fetchDetail(widget.groupId);
      if (!mounted) return;
      GoRouter.of(context).go('/group/details', extra: {'group': g});
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.generalError);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.groupInviteJoinTitle,
            style: GoogleFonts.robotoSerif(
                textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900))),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(widget.groupName ?? 'Group', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(t.groupInviteJoinSubtitle, textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Guest selection section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t.groupInviteGuestSelectTitle, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              Text(t.groupInviteGuestSelectSubtitle, textAlign: TextAlign.left),
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
                            child: Text(t.groupInviteNoGuestsFound, style: Theme.of(context).textTheme.bodySmall))
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _guestMembers.length,
                            itemBuilder: (context, index) {
                              final gm = _guestMembers[index];
                              return RadioListTile<String>(
                                title: Text(gm['display_name'] ?? gm['email']),
                                subtitle: Text(gm['email']),
                                value: gm['email'],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _joining ? null : _joinGroup,
                icon: _joining
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: Text(t.groupInviteTransferButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
