import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../main.dart';

class FriendAcceptPage extends StatefulWidget {
  const FriendAcceptPage({
    super.key,
    this.email,
    this.username,
    this.usernameCode,
  });

  final String? email;
  final String? username;
  final String? usernameCode;

  @override
  State<FriendAcceptPage> createState() => _FriendAcceptPageState();
}

class _FriendAcceptPageState extends State<FriendAcceptPage> {
  String? _error;
  SupaUser? _targetUser;
  bool _loading = true;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      SupaUser user;

      if (widget.username != null && widget.usernameCode != null) {
        // Look up by username+code (new QR format)
        user = await UserRepository.fetchByUsername(widget.username!, widget.usernameCode!);
      } else if (widget.email != null && widget.email!.isNotEmpty) {
        // Look up by email (legacy QR format / backward compat)
        user = await UserRepository.fetchDetail(widget.email!);
      } else {
        if (!mounted) return;
        setState(() {
          _error = AppLocalizations.of(context)!.generalError;
          _loading = false;
        });
        return;
      }

      // Block self-friendship
      if (user.email == supabase.auth.currentUser?.email) {
        if (!mounted) return;
        setState(() {
          _error = AppLocalizations.of(context)!.friendAcceptSelfError;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _targetUser = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await FriendshipRepository.accepted(_targetUser!.email);
      if (!mounted) return;
      sendFriendAcceptNotification(context, {_targetUser!.email});
      showSnackBar(
          context,
          AppLocalizations.of(context)!.friendshipAccept(_targetUser!.displayName));
      GoRouter.of(context).go('/friend');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _accepting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.requestFriendship)),
      body: Center(
        child: _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => GoRouter.of(context).go('/friend'),
                    child: Text(AppLocalizations.of(context)!.close),
                  )
                ],
              )
            : _loading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.loading),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: _avatarColor(_targetUser!.displayName),
                          child: Text(
                            _targetUser!.displayName.isNotEmpty
                                ? _targetUser!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.friendAcceptConfirmTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!
                              .friendAcceptConfirmBody(_targetUser!.displayName),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _targetUser!.fullUsername,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: _accepting
                                  ? null
                                  : () => GoRouter.of(context).go('/friend'),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _accepting ? null : _accept,
                              child: _accepting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(AppLocalizations.of(context)!.accept),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

Color _avatarColor(String name) {
  const colors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.teal, Colors.green,
    Colors.orange, Colors.brown,
  ];
  return colors[name.hashCode.abs() % colors.length];
}
