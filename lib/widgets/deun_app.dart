import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../constants.dart';
import 'theme_builder.dart';

/// Shared MaterialApp configuration for the pre-router screens (login,
/// onboarding). AuthGate swaps whole apps rather than routes, so until auth
/// gating moves into GoRouter redirects each top-level screen needs its own
/// MaterialApp — this keeps theme and localization config in one place and
/// consistent with the main app (NavigationScreen's MaterialApp.router).
class DeunApp extends StatelessWidget {
  const DeunApp({
    super.key,
    this.home,
    this.routes = const {},
    this.onUnknownRoute,
  });

  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory? onUnknownRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deun',
      theme: getThemeData(context, kBrandSeed, Brightness.light),
      darkTheme: getThemeData(context, kBrandSeed, Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      routes: routes,
      onUnknownRoute: onUnknownRoute,
    );
  }
}
