import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/motion.dart';
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
///
/// When [animate] is true the amount counts up from 0 on mount using a
/// [TweenAnimationBuilder] (750 ms, ease-out-cubic). The semantic color is
/// always resolved from the **final** [amount] (not the intermediate value)
/// so the color does not flicker across zero during the count.
/// Reduced motion (`MediaQuery.of(context).disableAnimations`) is respected:
/// when set the final value is shown immediately.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.semantic = MoneySemantic.neutral,
    this.style,
    this.showSign = false,
    this.textAlign,
    this.animate = false,
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

  /// When true, the amount animates from 0 to [amount] on mount (count-up).
  ///
  /// Reduced motion is respected: if `MediaQuery.of(context).disableAnimations`
  /// is true, the final amount is shown immediately with no tween.
  ///
  /// Defaults to false so existing usages are unchanged.
  final bool animate;

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

  Text _buildText(BuildContext context, double displayAmount) {
    final formatted = AppLocalizations.of(context)!.toCurrency(displayAmount);
    // showSign uses the final amount (not intermediate) so the "+" appears
    // exactly when the final value is positive — color and sign are consistent.
    final text = (showSign && amount > 0) ? '+$formatted' : formatted;

    final baseStyle = style ?? Theme.of(context).textTheme.titleMedium;
    // Color is always resolved from the FINAL amount, not displayAmount.
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

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.of(context).disableAnimations) {
      // Static path: exactly today's behavior.
      return _buildText(context, amount);
    }

    // Animated path: count up from 0 → amount.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: Motion.countUp,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _buildText(context, value),
    );
  }
}
