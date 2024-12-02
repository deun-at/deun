import 'package:flutter/material.dart';

import '../../main.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Settings')),
      body: Center(
        child: FilledButton(
            onPressed: () async {
              await supabase.auth.signOut();
            },
            child: const Text('sign out')),
      ),
    );
  }
}
