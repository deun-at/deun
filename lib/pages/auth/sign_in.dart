import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import '../../main.dart';

class SignUp extends StatelessWidget {
  const SignUp({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          SupaSocialsAuth(
            colored: true,
            nativeGoogleAuthConfig: const NativeGoogleAuthConfig(
              webClientId: '820724879316-jauhp8t8g5r3pmir1r5gsghbn2qchav5.apps.googleusercontent.com',
              iosClientId: '820724879316-8sacuk8sjju1rvr878gl9lqin0or5h9d.apps.googleusercontent.com',
            ),
            enableNativeAppleAuth: false,
            socialProviders: const [/*OAuthProvider.apple,*/ OAuthProvider.google, OAuthProvider.github],
            onError: (error) {
              debugPrint(error.toString());
            },
            onSuccess: (session) async {
              debugPrint(session.toString());
              debugPrint(session.user.userMetadata.toString());
              await supabase.from("user").upsert({
                'email': session.user.email,
                'user_id': session.user.id,
                'display_name': session.user.userMetadata?['name'] ?? session.user.userMetadata?['display_name'],
              });
            },
          ),
        ],
      ),
    );
  }
}
