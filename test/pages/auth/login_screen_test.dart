import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/auth/sign_in.dart';
import 'package:deun/pages/auth/social_auth_buttons.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  // Tall viewport so the whole scrollable form (incl. the mode-switch row at
  // the bottom) is laid out and findable without scrolling.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, brightness)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: const SignUp(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return null;
    },
  );

  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('login mode shows email + password + forgot + social + submit',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester);

    // App logo (the shared icon-512 asset), not the old fork glyph.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/icon/icon-512.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.call_split), findsNothing);
    // Login title.
    expect(find.text(l10n.authLoginTitle), findsOneWidget);
    // Email + password fields.
    expect(find.text(l10n.authEmailLabel), findsWidgets);
    expect(find.text(l10n.authPasswordLabel), findsWidgets);
    // No name field in login mode.
    expect(find.text(l10n.authNameLabel), findsNothing);
    // Forgot-password link.
    expect(find.text(l10n.authForgotPassword), findsOneWidget);
    // Social buttons present, rendered as white SecondaryButton cards with a
    // leading brand mark + the localized "Continue with …" labels (no M3
    // OutlinedButton pills).
    expect(find.byType(SocialAuthButtons), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      find.widgetWithText(SecondaryButton, l10n.authContinueWithGoogle),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SecondaryButton, l10n.authContinueWithGithub),
      findsOneWidget,
    );
    // Primary submit reads "Log in".
    expect(find.widgetWithText(PrimaryButton, l10n.authLoginCta), findsOneWidget);
    // Mode-switch action to sign up.
    expect(find.text(l10n.authSwitchToSignupAction), findsOneWidget);
  });

  testWidgets('switching to signup shows the name field and Create account CTA',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester);

    await tester.tap(find.text(l10n.authSwitchToSignupAction));
    await tester.pump();

    // Signup title + name field.
    expect(find.text(l10n.authSignupTitle), findsOneWidget);
    expect(find.text(l10n.authNameLabel), findsWidgets);
    // CTA flips to "Create account".
    expect(
      find.widgetWithText(PrimaryButton, l10n.authSignupCta),
      findsOneWidget,
    );
    // Forgot-password hidden in signup mode.
    expect(find.text(l10n.authForgotPassword), findsNothing);
    // Switch action now points back to login.
    expect(find.text(l10n.authSwitchToLoginAction), findsWidgets);
  });

  testWidgets('renders in dark mode without overflow/errors', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, brightness: Brightness.dark);

    expect(find.byIcon(Icons.call_split), findsNothing);
    expect(find.text(l10n.authLoginTitle), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, l10n.authLoginCta), findsOneWidget);
  });

  testWidgets('empty submit surfaces validation errors (no auth call)',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, l10n.authLoginCta));
    await tester.pump();

    expect(find.text(l10n.authEmailInvalid), findsOneWidget);
    expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
  });
}
