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

        // Check if password recovery was triggered
        bool isPasswordRecovery = false;

        if (session == null) {
          return const LoginScreen();
        }

        if (event == AuthChangeEvent.signedIn) {
          try {
            String? firstName;
            String? lastName;

            if (session.user.userMetadata?['full_name'] != null) {
              List<String> fullName = (session.user.userMetadata?['full_name'] as String).split(' ');

              if (fullName.isNotEmpty) {
                firstName = fullName[0];
                fullName.removeAt(0);
              }

              if (fullName.isNotEmpty) {
                lastName = fullName.join(' ');
              }
            }

            if (session.user.userMetadata?['first_name'] != null) {
              firstName = session.user.userMetadata?['first_name'];
            }

            if (session.user.userMetadata?['last_name'] != null) {
              lastName = session.user.userMetadata?['last_name'];
            }

            String displayName = session.user.userMetadata?['user_name'] ?? session.user.userMetadata?['name'];

            supabase.from("user").upsert({
              'email': session.user.email,
              'user_id': session.user.id,
              'first_name': firstName,
              'last_name': lastName,
              'display_name': displayName,
            }, ignoreDuplicates: true).whenComplete(() {});
          } catch (e) {
            debugPrint(e.toString());
          }
        } else if (event == null) {
        } else if (event == AuthChangeEvent.passwordRecovery) {
          isPasswordRecovery = true;
        }

        return NavigationScreen(isPasswordRecovery: isPasswordRecovery);
      },
    );
  }
}
