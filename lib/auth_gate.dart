import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import 'main.dart';
import 'navigation.dart';
import 'pages/auth/login_screen.dart';
import 'pages/auth/onboarding_screen.dart';

enum _AuthScreen { loading, onboarding, ready }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _AuthScreen _screenState = _AuthScreen.loading;
  bool _onboardingCheckStarted = false;
  String? _initialDisplayName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState?>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        if (session == null) {
          _resetState();
          return const LoginScreen();
        }

        if (event == AuthChangeEvent.signedIn) {
          _resetState();
          _upsertUserFromSession(session);
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          return NavigationScreen(isPasswordRecovery: true);
        }

        if (_screenState == _AuthScreen.loading) {
          if (!_onboardingCheckStarted) {
            _onboardingCheckStarted = true;
            _checkOnboarding();
          }
          return const SplashScreen();
        }

        if (_screenState == _AuthScreen.onboarding) {
          return OnboardingScreen(
            initialDisplayName: _initialDisplayName,
            onComplete: () {
              setState(() {
                _screenState = _AuthScreen.ready;
              });
            },
          );
        }

        return NavigationScreen(isPasswordRecovery: false);
      },
    );
  }

  void _checkOnboarding() {
    final email = supabase.auth.currentUser?.email ?? '';
    UserRepository.fetchDetail(email).then((user) {
      if (!mounted) return;
      setState(() {
        if (user.needsOnboarding) {
          _screenState = _AuthScreen.onboarding;
          _initialDisplayName = user.displayName;
        } else {
          _screenState = _AuthScreen.ready;
        }
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _screenState = _AuthScreen.ready;
      });
    });
  }

  void _resetState() {
    _screenState = _AuthScreen.loading;
    _onboardingCheckStarted = false;
    _initialDisplayName = null;
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
      }, ignoreDuplicates: true).catchError((e) {
        debugPrint('User upsert failed: $e');
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
