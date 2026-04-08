import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
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
        final Session? session = snapshot.data?.session;
        final AuthChangeEvent? event = snapshot.data?.event;

        // Check if password recovery was triggered
        bool isPasswordRecovery = false;

        if (session == null) {
          // Reset onboarding state on sign out
          _needsOnboarding = false;
          _onboardingChecked = false;
          _onboardingFuture = null;
          return const LoginScreen();
        }

        if (event == AuthChangeEvent.signedIn) {
          // Reset check so we re-evaluate on each sign-in
          _onboardingChecked = false;
          _needsOnboarding = false;
          _onboardingFuture = null;

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

            String? displayName = session.user.userMetadata?['user_name'] ?? session.user.userMetadata?['name'];

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
        } else if (event == null) {
        } else if (event == AuthChangeEvent.passwordRecovery) {
          isPasswordRecovery = true;
        }

        if (isPasswordRecovery) {
          return NavigationScreen(isPasswordRecovery: true);
        }

        // Check if user needs onboarding (no username set)
        if (!_onboardingChecked) {
          _onboardingFuture ??= UserRepository.fetchDetail(supabase.auth.currentUser?.email ?? '');
          return FutureBuilder<SupaUser>(
            future: _onboardingFuture,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                final brightness = MediaQuery.platformBrightnessOf(context);
                final bgColor = brightness == Brightness.dark
                    ? const Color(0xFF1f2021)
                    : const Color(0xFFefedee);
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: ColoredBox(
                    color: bgColor,
                    child: Center(
                      child: Image.asset('assets/icon/icon-512.png', height: 128),
                    ),
                  ),
                );
              }

              if (userSnapshot.hasData) {
                final user = userSnapshot.data!;
                _onboardingChecked = true;
                _needsOnboarding = user.needsOnboarding;
                _initialDisplayName = user.displayName;

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
}
