/// The two modes of the login / sign-up screen (Screen 1).
///
/// The screen owns this toggle itself (rather than delegating to the
/// `supabase_auth_ui` package widget) so the redesign can drive the title,
/// CTA, the name field and the forgot-password link from one place while the
/// underlying Supabase auth calls stay unchanged.
enum AuthMode { login, signup }

extension AuthModeX on AuthMode {
  /// The opposite mode — used by the mode-switch link at the bottom.
  AuthMode get toggled =>
      this == AuthMode.login ? AuthMode.signup : AuthMode.login;

  /// Whether the email form should currently sign in (vs. sign up). Mirrors the
  /// `_isSigningIn` flag inside the original `SupaEmailAuth` widget.
  bool get isSigningIn => this == AuthMode.login;

  /// The name field (display name on sign-up) is only collected when creating
  /// an account.
  bool get showsNameField => this == AuthMode.signup;

  /// Forgot-password is only offered in login mode (matches the original
  /// widget, which exposed it only while `_isSigningIn`).
  bool get showsForgotPassword => this == AuthMode.login;
}

/// Selects the localized screen title for [mode] from the two candidate
/// strings, keeping the mode→copy mapping pure and unit-testable. The caller
/// passes the already-localized "Welcome back" / "Create your account" strings.
String authTitleFor(
  AuthMode mode, {
  required String loginTitle,
  required String signupTitle,
}) =>
    mode == AuthMode.login ? loginTitle : signupTitle;

/// Selects the localized primary submit (CTA) label for [mode].
String authSubmitLabelFor(
  AuthMode mode, {
  required String loginLabel,
  required String signupLabel,
}) =>
    mode == AuthMode.login ? loginLabel : signupLabel;

/// Selects the localized mode-switch link label — the prompt to flip to the
/// other mode (e.g. "Don't have an account? Sign up").
String authSwitchLabelFor(
  AuthMode mode, {
  required String toSignupLabel,
  required String toLoginLabel,
}) =>
    mode == AuthMode.login ? toSignupLabel : toLoginLabel;
