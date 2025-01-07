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
        if (snapshot.data?.session == null) {
          return const LoginScreen();
        }

        try {
          supabase.from("user").insert({
            'email': snapshot.data?.session?.user.email,
            'user_id': snapshot.data?.session?.user.id,
            'display_name': snapshot.data?.session?.user.userMetadata?['name'],
          });
        } catch (e) {
          debugPrint(e.toString());
        } finally {
          debugPrint('User inserted');
        }

        return const NavigationScreen();
      },
    );
  }
}
