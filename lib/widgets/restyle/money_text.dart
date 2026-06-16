import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

/// How a [MoneyText] colors its amount.
enum MoneySemantic {
  /// Always the semantic success color.
  positive,

  /// Always the semantic danger color.
  negative,

  /// The default text color (no semantic tint).
  neutral,

  /// success for > 0, danger for < 0, default text color for 0.
  auto,
}

/// Renders a monetary [amount] via the locale-aware
/// `AppLocalizations.toCurrency`, in a tabular figure style, with an optional
/// semantic color and an optional explicit sign.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.semantic = MoneySemantic.neutral,
    this.style,
    this.showSign = false,
    this.textAlign,
  });

  /// The amount to display. Sign is taken from this value.
  final double amount;

  /// Color mode (see [MoneySemantic]).
  final MoneySemantic semantic;

  /// Optional text style override; defaults to `titleMedium` (already tabular
  /// in the redesign theme for display/headline; this also requests tabular
  /// figures explicitly so any slot aligns in columns).
  final TextStyle? style;

  /// When true, prefixes a leading "+" for positive amounts (negatives already
  /// carry their "−" from the formatter).
  final bool showSign;

  final TextAlign? textAlign;

  Color? _resolveColor(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    switch (semantic) {
      case MoneySemantic.positive:
        return semanticColors.success;
      case MoneySemantic.negative:
        return semanticColors.danger;
      case MoneySemantic.neutral:
        return null;
      case MoneySemantic.auto:
        if (amount > 0) return semanticColors.success;
        if (amount < 0) return semanticColors.danger;
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = AppLocalizations.of(context)!.toCurrency(amount);
    final text = (showSign && amount > 0) ? '+$formatted' : formatted;

    final baseStyle = style ?? Theme.of(context).textTheme.titleMedium;
    final color = _resolveColor(context);

    return Text(
      text,
      textAlign: textAlign,
      style: (baseStyle ?? const TextStyle()).copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
