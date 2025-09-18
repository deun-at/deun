import 'package:flutter/material.dart';

class ThemeBuilder extends StatelessWidget {
  const ThemeBuilder({super.key, required this.colorValue, required this.builder});

  final int colorValue;
  final Widget Function(BuildContext) builder;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorSeedValue = Color(colorValue);

    return Theme(
      data: getThemeData(context, colorSeedValue, themeData.brightness),
      child: Builder(builder: builder),
    );
  }
}

ThemeData getThemeData(BuildContext context, Color seedColor, Brightness brightness) {
  Color surface = Color(0xffefedee);
  Color surfaceBright = Color(0xfffef7ff);
  Color surfaceDim = Color(0xffded8e1);
  Color onSurface = Color(0xff1d1d1d);
  Color onSurfaceVariant = Color(0xff494949);
  Color surfaceContainerHighest = Color(0xffe4e4e4);
  Color surfaceContainerHigh = Color(0xffebebeb);
  Color surfaceContainer = Color(0xfff2f2f2);
  Color surfaceContainerLow = Color(0xfff5f5f5);
  Color surfaceContainerLowest = Color(0xffffffff);
  Color inverseSurface = Color(0xff323232);
  Color surfaceTint = Color(0xff7a7a7a);

  Color appBarBackgroundColor = Color(0xffefedee);

  if (brightness == Brightness.dark) {
    surface = Color(0xff1f2021);
    surfaceBright = Color(0xfffef7ff);
    surfaceDim = Color(0xffded8e1);
    onSurface = Color(0xffe4e4e4);
    onSurfaceVariant = Color(0xffcacaca);
    surfaceContainerHighest = Color(0xff373737);
    surfaceContainerHigh = Color(0xff2c2c2c);
    surfaceContainer = Color(0xff222222);
    surfaceContainerLow = Color(0xff1d1d1d);
    surfaceContainerLowest = Color(0xff101010);
    inverseSurface = Color(0xffe4e4e4);
    surfaceTint = Color(0xffdddddd);

    appBarBackgroundColor = Color(0xff1f2021);
  }

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness).copyWith(
      surface: surface,
      surfaceBright: surfaceBright,
      surfaceDim: surfaceDim,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: surfaceContainerLowest,
      inverseSurface: inverseSurface,
      surfaceTint: surfaceTint,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    appBarTheme: Theme.of(context).appBarTheme.copyWith(
          surfaceTintColor: Colors.transparent,
          backgroundColor: appBarBackgroundColor,
        ),
    cardTheme: Theme.of(context).cardTheme.copyWith(margin: EdgeInsets.fromLTRB(10, 1, 10, 1)),
    listTileTheme:
        Theme.of(context).listTileTheme.copyWith(contentPadding: EdgeInsetsDirectional.only(start: 16.0, end: 16.0)),
    searchViewTheme: Theme.of(context).searchViewTheme.copyWith(
          dividerColor: Colors.transparent,
        ),
  );
}
