import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';

class FriendAcceptPage extends StatefulWidget {
  const FriendAcceptPage({super.key, required this.email});

  final String? email;

  @override
  State<FriendAcceptPage> createState() => _FriendAcceptPageState();
}

class _FriendAcceptPageState extends State<FriendAcceptPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _accept();
  }

  Future<void> _accept() async {
    final email = widget.email;
    if (email == null || email.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.generalError);
      return;
    }

    try {
      await Friendship.accepted(email);
      if (!mounted) return;
      showSnackBar(
          context,
          rootScaffoldMessengerKey,
          AppLocalizations.of(context)!.friendshipAccept(email));
      // Go to friends list
      GoRouter.of(context).go('/friend');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.requestFriendship)),
      body: Center(
        child: _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => GoRouter.of(context).go('/friend'),
                    child: Text(AppLocalizations.of(context)!.close),
                  )
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.loading),
                ],
              ),
      ),
    );
  }
}
