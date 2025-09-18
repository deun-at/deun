import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/groups/group_model.dart';
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
  Future<void> _joinGroup() async {
    String? email = supabase.auth.currentUser?.email;
    if (email != null) {
      try {
        // Check if already member
        final existing = await supabase
            .from('group_member')
            .select('email')
            .eq('group_id', widget.groupId)
            .eq('email', email)
            .maybeSingle();

        debugPrint(existing.toString());

        if (existing == null) {
          await supabase.from('group_member').insert({
            'group_id': widget.groupId,
            'email': email,
          });

          // Update calculated shares
          await supabase.rpc('update_group_member_shares', params: {"_group_id": widget.groupId, "_expense_id": null});
        }

        // Now fetch detail (allowed as member) and navigate
        Group g = await Group.fetchDetail(widget.groupId);
        if (!mounted) return;
        GoRouter.of(context).go('/group/details', extra: {'group': g});
      } catch (e) {
        if (!mounted) return;
        showSnackBar(context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.generalError);
      }
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.groupInviteJoinTitle,
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
              Text(AppLocalizations.of(context)!.groupInviteJoinSubtitle, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _joinGroup,
                icon: const Icon(Icons.login),
                label: Text(AppLocalizations.of(context)!.groupInviteJoinButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
