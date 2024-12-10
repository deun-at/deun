import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import '../../constants.dart';
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
          SupaEmailAuth(
            redirectTo: kIsWeb ? null : 'io.supabase.flutter://',
            onSignInComplete: (response) {},
            onSignUpComplete: (response) async {
              Navigator.of(context).pushReplacementNamed('/');
            },
            metadataFields: [
              MetaDataField(
                prefixIcon: const Icon(Icons.person),
                label: 'Display Name',
                key: 'display_name',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a Display Name';
                  }
                  return null;
                },
              ),
            ],
          ),
          spacer,
          SupaSocialsAuth(
            colored: true,
            nativeGoogleAuthConfig: const NativeGoogleAuthConfig(
              webClientId: '820724879316-jauhp8t8g5r3pmir1r5gsghbn2qchav5.apps.googleusercontent.com',
              iosClientId: '820724879316-8sacuk8sjju1rvr878gl9lqin0or5h9d.apps.googleusercontent.com',
            ),
            enableNativeAppleAuth: false,
            socialProviders: const [/* OAuthProvider.apple, */ OAuthProvider.google],
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
