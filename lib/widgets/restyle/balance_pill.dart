import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

/// The settlement state a [BalancePill] conveys.
enum BalanceState { owed, owe, settled }

/// A small stadium pill summarizing a balance: success tint for "owed", danger
/// tint for "owe", neutral surface for "settled". Shows a [label] and an
/// optional [amount] (colored to match the state).
class BalancePill extends StatelessWidget {
  const BalancePill({
    super.key,
    required this.label,
    required this.state,
    this.amount,
  });

  final String label;
  final BalanceState state;

  /// Optional trailing amount; rendered with the matching semantic color.
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    final Color foreground;
    final Color background;
    final MoneySemantic moneySemantic;
    switch (state) {
      case BalanceState.owed:
        foreground = semantic.success;
        background = semantic.success.withValues(alpha: 0.14);
        moneySemantic = MoneySemantic.positive;
        break;
      case BalanceState.owe:
        foreground = semantic.danger;
        background = semantic.danger.withValues(alpha: 0.14);
        moneySemantic = MoneySemantic.negative;
        break;
      case BalanceState.settled:
        foreground = colorScheme.onSurfaceVariant;
        background = colorScheme.surfaceContainerHighest;
        moneySemantic = MoneySemantic.neutral;
        break;
    }

    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          if (amount != null) ...[
            const SizedBox(width: 6),
            MoneyText(
              amount!,
              semantic: moneySemantic,
              style: labelStyle,
            ),
          ],
        ],
      ),
    );
  }
}
