import 'dart:io' show Platform;

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/auth/auth_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deun/pages/auth/social_auth_buttons.dart';
import 'package:deun/widgets/restyle/primary_button.dart';

/// Pragmatic email shape check (same intent as the package's email validator):
/// a non-empty local part, an `@`, a domain with at least one dot.
final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Screen 1 — Login / Sign-up (redesign).
///
/// A presentation-only restyle: the social OAuth flow is still the
/// `supabase_auth_ui` [SupaSocialsAuth] widget (native Google/Apple, anonymous
/// linking, OAuth launch), and the email/password form makes the exact same
/// Supabase calls the package's `SupaEmailAuth` made — `signInWithPassword`,
/// `signUp` (with the anonymous-user `updateUser` branch), and
/// `resetPasswordForEmail`. Only the layout, fields and copy are new so the
/// app can own the login/sign-up mode switch and drive the redesigned chrome.
class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocusNode = FocusNode();

  AuthMode _mode = AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;

  /// Native redirect deep link used by both the email and social flows on
  /// non-web platforms (unchanged from the original screen).
  static const _nativeRedirect = 'app.deun.www://login-callback';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  List<OAuthProvider> get _oAuthProviders {
    final providers = [OAuthProvider.google, OAuthProvider.github];
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      providers.insert(0, OAuthProvider.apple); // Apple only on native iOS/macOS
    }
    return providers;
  }

  void _toggleMode() {
    setState(() => _mode = _mode.toggled);
  }

  void _navigateHome(AuthResponse response) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showError(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.error,
        ),
      );
  }

  /// Submit the email/password form. Mirrors `SupaEmailAuth._signInSignUp`:
  /// login → `signInWithPassword`; sign-up → `signUp` (or `updateUser` when the
  /// current user is anonymous), passing the display name as `user_metadata`.
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_mode.isSigningIn) {
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        _navigateHome(response);
      } else {
        final data = <String, dynamic>{
          'name': _nameController.text.trim(),
        };
        final user = supabase.auth.currentUser;
        late final AuthResponse response;
        if (user?.isAnonymous == true) {
          await supabase.auth.updateUser(
            UserAttributes(email: email, password: password, data: data),
            emailRedirectTo: kIsWeb ? null : _nativeRedirect,
          );
          response = AuthResponse(session: supabase.auth.currentSession);
        } else {
          response = await supabase.auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: kIsWeb ? null : _nativeRedirect,
            data: data,
          );
        }
        _navigateHome(response);
      }
    } on AuthException catch (error) {
      _showError(error.message);
      _emailFocusNode.requestFocus();
    } catch (error) {
      _showError(l10n.authUnexpectedError);
      _emailFocusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Forgot-password — mirrors `SupaEmailAuth._passwordRecovery`: validates the
  /// email, calls `resetPasswordForEmail`, and confirms via a snackbar.
  Future<void> _recoverPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _emailFocusNode.requestFocus();
      _showError(l10n.authEmailInvalid);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : _nativeRedirect,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.authPasswordResetSent)));
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

    final title = authTitleFor(
      _mode,
      loginTitle: l10n.authLoginTitle,
      signupTitle: l10n.authSignupTitle,
    );
    final submitLabel = authSubmitLabelFor(
      _mode,
      loginLabel: l10n.authLoginCta,
      signupLabel: l10n.authSignupCta,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                // App icon: call_split per spec.
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.call_split,
                    size: 36,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authSubtitle,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Social buttons (Apple dark / Google / GitHub) — existing
                // OAuth logic via SupaSocialsAuth, restyled labels.
                SocialAuthButtons(
                  providers: _oAuthProviders,
                  googleWebClientId: kGoogleWebClientId,
                  googleIosClientId: kGoogleIosClientId,
                  launchMode: kIsWeb
                      ? LaunchMode.platformDefault
                      : LaunchMode.externalApplication,
                  redirectUrl: kIsWeb ? null : _nativeRedirect,
                  unexpectedErrorMessage: l10n.authUnexpectedError,
                  onError: _showError,
                  labels: {
                    OAuthProvider.apple: l10n.authContinueWithApple,
                    OAuthProvider.google: l10n.authContinueWithGoogle,
                    OAuthProvider.github: l10n.authContinueWithGithub,
                  },
                ),
                const SizedBox(height: 20),

                _OrDivider(label: l10n.authDividerOr),
                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mode.showsNameField) ...[
                        _InsetField(
                          controller: _nameController,
                          label: l10n.authNameLabel,
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.authNameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      _InsetField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        label: l10n.authEmailLabel,
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !_emailRegex.hasMatch(value.trim())) {
                            return l10n.authEmailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _InsetField(
                        controller: _passwordController,
                        label: l10n.authPasswordLabel,
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        autofillHints: _mode.isSigningIn
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return l10n.authPasswordTooShort;
                          }
                          return null;
                        },
                      ),
                      if (_mode.showsForgotPassword)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _recoverPassword,
                            child: Text(l10n.authForgotPassword),
                          ),
                        ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        onPressed: _isLoading ? null : _submit,
                        label: submitLabel,
                        loading: _isLoading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        authSwitchLabelFor(
                          _mode,
                          toSignupLabel: l10n.authSwitchToSignupPrompt,
                          toLoginLabel: l10n.authSwitchToLoginPrompt,
                        ),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(
                          authSwitchLabelFor(
                            _mode,
                            toSignupLabel: l10n.authSwitchToSignupAction,
                            toLoginLabel: l10n.authSwitchToLoginAction,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Legal microcopy footer (v3): muted, centered caption under
                // the CTA. ponytail: plain text now; wire real Terms/Privacy
                // URLs when they exist.
                Text(
                  l10n.authLegalDisclaimer,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A divider with a centered "or" label between the social and email options.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// A restyled inset text field on the field-fill surface, matching the
/// redesign's soft inputs (radius 16, no hard border, leading icon).
class _InsetField extends StatelessWidget {
  const _InsetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        suffixIcon: suffix,
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
