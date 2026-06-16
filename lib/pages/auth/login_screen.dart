import 'package:deun/pages/settings/contact.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:deun/widgets/deun_app.dart';
import 'package:flutter/material.dart';

import './sign_in.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeunApp(
      routes: {
        '/': (context) => const SignUp(),
        '/privacy-policy': (context) => const PrivacyPolicy(),
        '/contact': (context) => const Contact(),
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
