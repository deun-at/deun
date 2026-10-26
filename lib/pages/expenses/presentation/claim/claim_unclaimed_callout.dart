import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

/// Warning-tinted callout shown above the items while some units are still
/// unclaimed, with a Nudge action.
class ClaimUnclaimedCallout extends StatelessWidget {
  const ClaimUnclaimedCallout({
    super.key,
    required this.unclaimed,
    required this.payerName,
    required this.onNudge,
    required this.currency,
  });

  final double unclaimed;
  final String payerName;
  final VoidCallback onNudge;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: semantic.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      // F130: explanatory copy (amount + payer covers the rest) with a solid
      // black (ink/onInk) "Nudge" pill instead of a plain text link.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: semantic.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.claimUnclaimedCallout(
                    l10n.toCurrency(unclaimed, currency.code),
                    payerName,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: semantic.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _NudgePill(onTap: onNudge, label: l10n.claimNudge),
          ),
        ],
      ),
    );
  }
}

/// The solid black (ink/onInk) "Nudge" pill in the unclaimed callout (F130).
class _NudgePill extends StatelessWidget {
  const _NudgePill({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: semantic.ink,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: semantic.onInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
