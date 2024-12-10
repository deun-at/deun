import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import 'provider.dart';
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

        return const NavigationScreen();
      },
    );
  }
}
