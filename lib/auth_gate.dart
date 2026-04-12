import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import 'main.dart';
import 'navigation.dart';
import 'pages/auth/login_screen.dart';
import 'pages/auth/onboarding_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _needsOnboarding = false;
  bool _onboardingChecked = false;
  String? _initialDisplayName;
  Future<SupaUser>? _onboardingFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState?>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        if (session == null) {
          _resetOnboardingState();
          return const LoginScreen();
        }

        if (event == AuthChangeEvent.signedIn) {
          _resetOnboardingState();
          _upsertUserFromSession(session);
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          return NavigationScreen(isPasswordRecovery: true);
        }

        if (!_onboardingChecked) {
          _onboardingFuture ??= UserRepository.fetchDetail(
            supabase.auth.currentUser?.email ?? '',
          );
          return FutureBuilder<SupaUser>(
            future: _onboardingFuture,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

    
              if (userSnapshot.hasData) {
                final user = userSnapshot.data!;
                _onboardingChecked = true;
                _needsOnboarding = user.needsOnboarding;
                _initialDisplayName = user.displayName;

                if (user.needsOnboarding) {
                  return OnboardingScreen(
                    initialDisplayName: user.displayName,
                    onComplete: () {
                      setState(() {
                        _needsOnboarding = false;
                      });
                    },
                  );
                }
              }

              return NavigationScreen(isPasswordRecovery: false);
            },
          );
        }

        if (_needsOnboarding) {
          return OnboardingScreen(
            initialDisplayName: _initialDisplayName,
            onComplete: () {
              setState(() {
                _needsOnboarding = false;
              });
            },
          );
        }

        return NavigationScreen(isPasswordRecovery: false);
      },
    );
  }

  void _resetOnboardingState() {
    _needsOnboarding = false;
    _onboardingChecked = false;
    _onboardingFuture = null;
  }

  void _upsertUserFromSession(Session session) {
    try {
      String? firstName;
      String? lastName;

      if (session.user.userMetadata?['full_name'] != null) {
        final fullName =
            (session.user.userMetadata?['full_name'] as String).split(' ');
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

      final displayName = session.user.userMetadata?['user_name'] ??
          session.user.userMetadata?['name'];

      supabase.from("user").upsert({
        'email': session.user.email,
        'user_id': session.user.id,
        'first_name': firstName,
        'last_name': lastName,
        'display_name': displayName ?? '-',
      }, ignoreDuplicates: true).whenComplete(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
