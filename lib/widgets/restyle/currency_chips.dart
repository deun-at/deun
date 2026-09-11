import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:flutter/material.dart';
import 'package:deun/widgets/theme_builder.dart';

/// One currency's net: its ISO code over the bare amount, tinted by direction.
///
/// The shape every surface uses to state a balance it holds in more than one
/// currency — the home hero and the friend sheet. A single figure cannot stand
/// for a multi-currency balance (there is no total across currencies), and
/// hiding the remainder behind a disclosure makes a debt something the user has
/// to go looking for. One chip each, all visible, is the answer in both places.
///
/// The label is the CURRENCY, not a direction: the direction is already in the
/// sign and the tint, and the currency is the thing the user cannot otherwise
/// tell. The amount carries no code of its own — the label above it has done
/// the identifying.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({super.key, required this.entry, this.labelColor});

  final CurrencyAmount entry;

  /// Colour for the code label. Defaults to `onSurfaceVariant`; the ink hero
  /// passes its own muted-on-dark colour.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    final tint = entry.amount < 0 ? semantic.danger : semantic.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.currency.code,
            style: theme.textTheme.labelMedium?.copyWith(
              color: labelColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          MoneyText(
            entry.amount,
            currency: entry.currency,
            semantic: MoneySemantic.auto,
            showSymbol: false,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every currency of a balance, one [CurrencyChip] each, wrapping.
class CurrencyChips extends StatelessWidget {
  const CurrencyChips({super.key, required this.entries, this.labelColor});

  final List<CurrencyAmount> entries;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in entries)
        CurrencyChip(entry: entry, labelColor: labelColor),
    ],
  );
}
