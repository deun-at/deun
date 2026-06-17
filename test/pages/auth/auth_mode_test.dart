import 'package:deun/pages/auth/auth_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthMode.toggled', () {
    test('flips between login and signup', () {
      expect(AuthMode.login.toggled, AuthMode.signup);
      expect(AuthMode.signup.toggled, AuthMode.login);
    });
  });

  group('AuthMode flags', () {
    test('login mode signs in, hides name field, shows forgot-password', () {
      expect(AuthMode.login.isSigningIn, true);
      expect(AuthMode.login.showsNameField, false);
      expect(AuthMode.login.showsForgotPassword, true);
    });

    test('signup mode does not sign in, shows name field, hides forgot-password',
        () {
      expect(AuthMode.signup.isSigningIn, false);
      expect(AuthMode.signup.showsNameField, true);
      expect(AuthMode.signup.showsForgotPassword, false);
    });
  });

  group('copy selectors', () {
    test('authTitleFor picks the right localized title', () {
      expect(
        authTitleFor(AuthMode.login,
            loginTitle: 'Welcome back', signupTitle: 'Create your account'),
        'Welcome back',
      );
      expect(
        authTitleFor(AuthMode.signup,
            loginTitle: 'Welcome back', signupTitle: 'Create your account'),
        'Create your account',
      );
    });

    test('authSubmitLabelFor picks the right CTA', () {
      expect(
        authSubmitLabelFor(AuthMode.login,
            loginLabel: 'Log in', signupLabel: 'Create account'),
        'Log in',
      );
      expect(
        authSubmitLabelFor(AuthMode.signup,
            loginLabel: 'Log in', signupLabel: 'Create account'),
        'Create account',
      );
    });

    test('authSwitchLabelFor picks the right mode-switch prompt', () {
      expect(
        authSwitchLabelFor(AuthMode.login,
            toSignupLabel: 'Sign up', toLoginLabel: 'Log in'),
        'Sign up',
      );
      expect(
        authSwitchLabelFor(AuthMode.signup,
            toSignupLabel: 'Sign up', toLoginLabel: 'Log in'),
        'Log in',
      );
    });
  });
}
