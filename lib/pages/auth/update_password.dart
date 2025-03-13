import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:deun/l10n/app_localizations.dart';

class UpdatePassword extends StatelessWidget {
  const UpdatePassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.updatePasswordTitle), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SupaResetPassword(
              accessToken: Supabase.instance.client.auth.currentSession!.accessToken,
              onSuccess: (response) {
                GoRouter.of(context).go('/group');
              },
              localization: SupaResetPasswordLocalization(
                enterPassword: AppLocalizations.of(context)!.updatePasswordEnterPassword,
                passwordLengthError: AppLocalizations.of(context)!.updatePasswordPasswordLengthError,
                passwordResetSent: AppLocalizations.of(context)!.updatePasswordPasswordResetSent,
                unexpectedError: AppLocalizations.of(context)!.updatePasswordunexpectedError,
                updatePassword: AppLocalizations.of(context)!.updatePasswordUpdatePassword,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
