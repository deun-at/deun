import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import '../../constants.dart';

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
            onSignInComplete:(response) {},
            onSignUpComplete: (response) {},
            metadataFields: [
              MetaDataField(
                prefixIcon: const Icon(Icons.person),
                label: 'Username',
                key: 'username',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter something';
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
              webClientId: '81959600219-11bd727f843jmkus0cijmov1724k7rob.apps.googleusercontent.com',
              iosClientId: 'YOUR_IOS_CLIENT_ID',
            ),
            enableNativeAppleAuth: false,
            socialProviders: const [ /* OAuthProvider.apple, */ OAuthProvider.google ],
            onSuccess: (session) {},
          ),
        ],
      ),
    );
  }
}
