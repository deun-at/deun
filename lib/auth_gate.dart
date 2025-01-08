import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import 'main.dart';
import 'navigation.dart';
import 'pages/auth/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState?>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final Session? session = snapshot.data?.session;
        final AuthChangeEvent? event = snapshot.data?.event;

        if (session == null) {
          return const LoginScreen();
        }

        if (event == AuthChangeEvent.signedIn) {
          try {
            supabase.from("user").upsert({
              'email': session.user.email,
              'user_id': session.user.id,
              'display_name': session.user.userMetadata?['name'],
            }, ignoreDuplicates: true).whenComplete(() {});
          } catch (e) {
            debugPrint(e.toString());
          }
        }

        return const NavigationScreen();
      },
    );
  }
}
