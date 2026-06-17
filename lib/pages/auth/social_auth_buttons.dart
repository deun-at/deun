import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deun/main.dart' show supabase;

/// Brand icon for a supported OAuth provider (font_awesome v11 `FaIconData`).
FaIconData _brandIcon(OAuthProvider provider) => switch (provider) {
      OAuthProvider.apple => FontAwesomeIcons.apple,
      OAuthProvider.google => FontAwesomeIcons.google,
      OAuthProvider.github => FontAwesomeIcons.github,
      _ => FontAwesomeIcons.rightToBracket,
    };

/// Owned replacement for `supabase_auth_ui`'s `SupaSocialsAuth`.
///
/// Reproduces the package's auth behaviour for the providers the app uses —
/// native Google Sign-In (Android/iOS), native Sign in with Apple (iOS/macOS),
/// anonymous-account linking via `linkIdentity`, and an OAuth-launch fallback —
/// while leaving the button styling to the redesign. The package itself is
/// abandoned against Flutter 3.44 (it subclasses the now-final `IconData`), so
/// we own this small slice instead of carrying the dependency.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.providers,
    required this.labels,
    required this.onError,
    required this.unexpectedErrorMessage,
    this.googleWebClientId,
    this.googleIosClientId,
    this.enableNativeAppleAuth = true,
    this.redirectUrl,
    this.launchMode = LaunchMode.platformDefault,
  });

  /// Providers to render, in order.
  final List<OAuthProvider> providers;

  /// Localized button label per provider.
  final Map<OAuthProvider, String> labels;

  /// Called with a user-facing message when a sign-in attempt fails.
  final void Function(String message) onError;

  /// Fallback message for non-[AuthException] errors.
  final String unexpectedErrorMessage;

  /// Web Client ID registered with Google Cloud — enables native Google Sign-In
  /// on Android (server client id).
  final String? googleWebClientId;

  /// iOS Client ID registered with Google Cloud — enables native Google Sign-In
  /// on iOS.
  final String? googleIosClientId;

  /// Whether to use native Sign in with Apple on iOS/macOS.
  final bool enableNativeAppleAuth;

  /// Deep-link redirect passed to the OAuth / link flows on native platforms.
  final String? redirectUrl;

  /// Launch mode for the browser-based OAuth fallback.
  final LaunchMode launchMode;

  /// Native Google Sign-In → Supabase id-token exchange (Android/iOS).
  Future<void> _nativeGoogleSignIn() async {
    final googleSignIn = GoogleSignIn(
      clientId: googleIosClientId,
      serverClientId: googleWebClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw const AuthException(
          'No Access Token found from Google sign in result.');
    }
    if (idToken == null) {
      throw const AuthException(
          'No ID Token found from Google sign in result.');
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Native Sign in with Apple → Supabase id-token exchange (iOS/macOS).
  Future<void> _nativeAppleSignIn() async {
    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
          'Could not find ID Token from generated Apple sign in credential.');
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Future<void> _onPressed(OAuthProvider provider) async {
    try {
      // Native Google Sign-In where a matching client id is configured.
      if (provider == OAuthProvider.google) {
        final shouldUseNative =
            (googleWebClientId != null && !kIsWeb && Platform.isAndroid) ||
                (googleIosClientId != null && !kIsWeb && Platform.isIOS);
        if (shouldUseNative) {
          await _nativeGoogleSignIn();
          return;
        }
      }

      // Native Sign in with Apple on iOS/macOS.
      if (provider == OAuthProvider.apple) {
        final shouldUseNative = enableNativeAppleAuth &&
            !kIsWeb &&
            (Platform.isIOS || Platform.isMacOS);
        if (shouldUseNative) {
          await _nativeAppleSignIn();
          return;
        }
      }

      // Anonymous users link the identity instead of starting a new session.
      final user = supabase.auth.currentUser;
      if (user?.isAnonymous == true) {
        await supabase.auth.linkIdentity(provider, redirectTo: redirectUrl);
        return;
      }

      await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectUrl,
        authScreenLaunchMode: launchMode,
      );
    } on AuthException catch (error) {
      onError(error.message);
    } catch (error) {
      onError('$unexpectedErrorMessage: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in providers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _onPressed(provider),
                icon: FaIcon(_brandIcon(provider), size: 20),
                label: Text(labels[provider] ?? provider.name),
              ),
            ),
          ),
      ],
    );
  }
}
