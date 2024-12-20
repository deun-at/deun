import 'package:flutter/material.dart';

import '../../constants.dart';

import './sign_in.dart';
// import './update_password.dart';
// import './phone_sign_in.dart';
// import './verify_phone.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const SignUp(),
        // '/update_password': (context) => const UpdatePassword(),
        // '/phone_sign_in': (context) => const PhoneSignIn(),
        // '/phone_sign_up': (context) => const PhoneSignUp(),
        // '/verify_phone': (context) => const VerifyPhone(),
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
