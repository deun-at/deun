import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pragmatic email shape check — same regex the login form uses.
final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Dedicated "Reset your password" screen (design F36).
///
/// Reached from the login screen's "Forgot password?" link. Mirrors
/// [UpdatePassword]'s scaffold (header + title + subtitle + one field +
/// primary button). The Supabase call is the same
/// `supabase.auth.resetPasswordForEmail` that lived inline in
/// `sign_in.dart`'s `_recoverPassword`; it is unchanged, just relocated here so
/// the flow is a full screen instead of a snackbar depending on the login
/// email field.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  /// Native redirect deep link — same value the login screen uses.
  static const _nativeRedirect = 'app.deun.www://login-callback';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: colorScheme.error),
      );
  }

  /// Lifted verbatim from `sign_in.dart`'s `_recoverPassword`: validate the
  /// email, call `resetPasswordForEmail`, confirm via a snackbar. On success we
  /// pop back to the login screen.
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : _nativeRedirect,
      );
      if (!mounted) return;
      // Show the confirmation on the app-level messenger (survives the pop),
      // then return to the login screen.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.authPasswordResetSent)));
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(l10n.authUnexpectedError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          DeunHeader(title: l10n.resetPasswordTitle),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.lock_reset_outlined,
                          size: 34,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.resetPasswordTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.resetPasswordInstructions,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: l10n.authEmailLabel,
                              labelMode: AppTextFieldLabelMode.placeholder,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty ||
                                    !_emailRegex.hasMatch(value.trim())) {
                                  return l10n.authEmailInvalid;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            PrimaryButton(
                              onPressed: _isLoading ? null : _submit,
                              label: l10n.resetPasswordSendLink,
                              loading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
