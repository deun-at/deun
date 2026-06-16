import 'package:flutter/material.dart';

/// Semantic colors that M3's [ColorScheme] does not model (success / danger /
/// warning, plus the ledger payback-chip pair). Provided via a
/// [ThemeExtension] so they resolve through `Theme.of(context)` and flip with
/// brightness, keeping widgets free of hard-coded hex.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.danger,
    required this.warning,
    required this.paybackBackground,
    required this.paybackText,
  });

  /// Owed / positive (e.g. "you're owed", lent, settled).
  final Color success;

  /// Owe / negative (e.g. "you owe", delete, over-allocated).
  final Color danger;

  /// Unclaimed / amber callouts (e.g. favorite star).
  final Color warning;

  /// Background for the ledger payback / payment chip.
  final Color paybackBackground;

  /// Text/foreground for the ledger payback / payment chip.
  final Color paybackText;

  /// Light-mode values (DESIGN_SPEC "Color tokens").
  static const SemanticColors light = SemanticColors(
    success: Color(0xFF1A8F5E),
    danger: Color(0xFFD85A47),
    warning: Color(0xFFC98A2E),
    paybackBackground: Color(0xFFEAF6EF),
    paybackText: Color(0xFF2F7A55),
  );

  /// Dark-mode values: the lighter on-dark semantic variants so they stay
  /// legible on dark surfaces (DESIGN_SPEC "Dark mode palette"). The payback
  /// pair has no spec dark value; bg/text are a v0 derivation toward the
  /// dark surface family.
  static const SemanticColors dark = SemanticColors(
    success: Color(0xFF4ED99B),
    danger: Color(0xFFF2937F),
    warning: Color(0xFFF2C97F),
    paybackBackground: Color(0xFF1E3A2C),
    paybackText: Color(0xFF5FA882),
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? danger,
    Color? warning,
    Color? paybackBackground,
    Color? paybackText,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      paybackBackground: paybackBackground ?? this.paybackBackground,
      paybackText: paybackText ?? this.paybackText,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      paybackBackground: Color.lerp(paybackBackground, other.paybackBackground, t)!,
      paybackText: Color.lerp(paybackText, other.paybackText, t)!,
    );
  }
}

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
  // Light: warm-neutral surfaces from the prototype palette.
  Color surface = const Color(0xFFF4F3EF);
  Color surfaceBright = const Color(0xFFFBFAF7);
  Color surfaceDim = const Color(0xFFEAE8E1);
  Color onSurface = const Color(0xFF16181A);
  Color onSurfaceVariant = const Color(0xFF56524A);
  Color surfaceContainerHighest = const Color(0xFFF0EEE8);
  Color surfaceContainerHigh = const Color(0xFFEAE8E1);
  Color surfaceContainer = const Color(0xFFF1EFE9);
  Color surfaceContainerLow = const Color(0xFFFBFAF7);
  Color surfaceContainerLowest = const Color(0xFFFFFFFF);
  Color inverseSurface = const Color(0xFF2A2C28);
  Color surfaceTint = const Color(0xFF7A7A7A);

  Color appBarBackgroundColor = const Color(0xFFFBFAF7);

  if (brightness == Brightness.dark) {
    // Dark: warm near-black surfaces derived from the prototype palette.
    surface = const Color(0xFF121311);
    surfaceBright = const Color(0xFF262824);
    surfaceDim = const Color(0xFF121311);
    onSurface = const Color(0xFFECEBE6);
    onSurfaceVariant = const Color(0xFF9A968C);
    surfaceContainerHighest = const Color(0xFF373B35);
    surfaceContainerHigh = const Color(0xFF2E302B);
    surfaceContainer = const Color(0xFF262824);
    surfaceContainerLow = const Color(0xFF1A1B19);
    surfaceContainerLowest = const Color(0xFF1F211E);
    inverseSurface = const Color(0xFFECEBE6);
    surfaceTint = const Color(0xFFDDDDDD);

    appBarBackgroundColor = const Color(0xFF1A1B19);
  }

  return ThemeData(
    extensions: <ThemeExtension<dynamic>>[
      brightness == Brightness.dark ? SemanticColors.dark : SemanticColors.light,
    ],
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
    cardTheme: Theme.of(context).cardTheme.copyWith(margin: const EdgeInsets.fromLTRB(10, 1, 10, 1)),
    listTileTheme:
        Theme.of(context).listTileTheme.copyWith(contentPadding: const EdgeInsetsDirectional.only(start: 16.0, end: 16.0)),
    searchViewTheme: Theme.of(context).searchViewTheme.copyWith(
          dividerColor: Colors.transparent,
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: StadiumBorder(),
      elevation: 3,
      extendedPadding: EdgeInsets.symmetric(horizontal: 20),
      extendedTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),
  );
}
