import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:deun/l10n/app_localizations.dart';

class SignUp extends StatelessWidget {
  const SignUp({super.key});
  @override
  Widget build(BuildContext context) {
    void navigateHome(AuthResponse response) {
      Navigator.of(context).pushReplacementNamed('/');
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.signInTitle), centerTitle: true),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24.0),
        children: [
          Image.asset(
            'assets/icon/icon-512.png',
            height: 100,
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.signInSubtitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.signInDescription,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SupaSocialsAuth(
            colored: true,
            nativeGoogleAuthConfig: const NativeGoogleAuthConfig(
              webClientId: '820724879316-jauhp8t8g5r3pmir1r5gsghbn2qchav5.apps.googleusercontent.com',
              iosClientId: '820724879316-8sacuk8sjju1rvr878gl9lqin0or5h9d.apps.googleusercontent.com',
            ),
            authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
            enableNativeAppleAuth: false,
            socialProviders: const [OAuthProvider.google, /*OAuthProvider.apple, */ OAuthProvider.github],
            redirectUrl: kIsWeb ? null : 'app.deun.www://login-callback',
            onSuccess: (session) {},
          ),
          const SizedBox(height: 20),
          const Divider(),
          Text(
            AppLocalizations.of(context)!.signInEmailTitle,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SupaEmailAuth(
            redirectTo: kIsWeb ? null : 'app.deun.www://login-callback',
            onSignInComplete: navigateHome,
            onSignUpComplete: navigateHome,
            metadataFields: [
              MetaDataField(
                prefixIcon: const Icon(Icons.person),
                label: AppLocalizations.of(context)!.settingsFirstName,
                key: 'first_name',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return AppLocalizations.of(context)!.settingsFirstNameValidationEmpty;
                  }
                  return null;
                },
              ),
              MetaDataField(
                prefixIcon: const Icon(Icons.person),
                label: AppLocalizations.of(context)!.settingsLastName,
                key: 'last_name',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return AppLocalizations.of(context)!.settingsLastNameValidationEmpty;
                  }
                  return null;
                },
              ),
              MetaDataField(
                prefixIcon: const Icon(Icons.person),
                label: AppLocalizations.of(context)!.settingsDisplayName,
                key: 'user_name',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return AppLocalizations.of(context)!.settingsDisplayNameValidationEmpty;
                  }
                  return null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
