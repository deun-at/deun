import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/groups/group_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deun/l10n/app_localizations.dart';

class GroupJoinPage extends StatefulWidget {
  const GroupJoinPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  Group? _group;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      Group g = await Group.fetchDetail(widget.groupId);
      setState(() {
        _group = g;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_group == null) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Check if already member
      final existing = await supabase
          .from('group_member')
          .select('email')
          .eq('group_id', _group!.id)
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (existing == null) {
        await supabase.from('group_member').insert({
          'group_id': _group!.id,
          'email': user.email,
        });

        // Update calculated shares
        await supabase.rpc('update_group_member_shares', params: {"_group_id": _group!.id, "_expense_id": null});
      }

      if (!mounted) return;
      // Navigate to group details
      GoRouter.of(context).go('/group/details', extra: {'group': _group});
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, rootScaffoldMessengerKey, AppLocalizations.of(context)!.generalError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join group',
            style: GoogleFonts.robotoSerif(
                textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900))),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(AppLocalizations.of(context)!.errorLoadingData),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 64, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(_group!.name, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text('Join this group to view and add expenses.', textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _joinGroup,
                          icon: const Icon(Icons.login),
                          label: const Text('Enter group'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
