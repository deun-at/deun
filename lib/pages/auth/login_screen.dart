import 'package:deun/pages/auth/update_password.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../constants.dart';

import './sign_in.dart';

void main() {
  runApp(const LoginScreen());
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deun',
      theme: ThemeData(colorSchemeSeed: ColorSeed.baseColor.color, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: ColorSeed.baseColor.color, useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (context) => const SignUp(),
        '/update-password': (context) => const UpdatePassword(),
        '/privacy-policy': (context) => const PrivacyPolicy(),
      },
      onUnknownRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const Scaffold(
            body: Center(
              child: Text(
                'Not Found',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
