import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/restyle/money_text.dart';
import '../../../../widgets/restyle/primary_button.dart';
import '../../../../widgets/theme_builder.dart';

/// Itemized header: the live total summed from the item line totals, with a
/// Scan action that triggers the existing receipt scanner.
class EditorItemizedTotalHeader extends StatelessWidget {
  const EditorItemizedTotalHeader({
    super.key,
    required this.screenContext,
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.onScan,
  });

  /// The screen's own context, above the group's `ThemeBuilder`: the header's
  /// colours come from the app's brand theme, not the group's.
  final BuildContext screenContext;
  final int itemCount;
  final double total;
  final Currency currency;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(screenContext);
    final colorScheme = theme.colorScheme;
    final ink = theme.extension<SemanticColors>()!;
    // v3: unboxed total block — sits directly on the page background (no
    // SoftCard), mirroring the F103 quick-header unboxing. Small grey label +
    // big amount on the left, dark-ink Scan pill on the right.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.itemizedTotalFromItems(itemCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              MoneyText(
                total,
                currency: currency,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        // v3: dark-ink solid pill labeled "Scan" (not a light indigo tint).
        PrimaryButton(
          label: l10n.expenseScanShort,
          icon: Icons.document_scanner_outlined,
          background: ink.ink,
          foreground: ink.onInk,
          onPressed: onScan,
          compact: true,
        ),
      ],
    );
  }
}

/// Tinted info callout explaining itemized / claiming. Uses a primary tint,
/// never a hard-coded hex.
class EditorItemizedInfoCallout extends StatelessWidget {
  const EditorItemizedInfoCallout({super.key, required this.screenContext});

  /// The screen's own context, above the group's `ThemeBuilder`: the callout's
  /// colours come from the app's brand theme, not the group's.
  final BuildContext screenContext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(screenContext);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.itemizedInfoCallout,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
