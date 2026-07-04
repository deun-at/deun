import 'package:flutter/material.dart';

import 'package:deun/l10n/app_localizations.dart';

/// A compact ± stepper: a rounded track with a minus button, a value display,
/// and a plus button. The buttons fire [onDecrement] / [onIncrement] only while
/// [canDecrement] / [canIncrement] are true (so callers can enforce min/max).
class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.canIncrement = true,
    this.canDecrement = true,
  });

  /// The current value, pre-formatted by the caller.
  final String value;

  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  /// When false the plus button is disabled and [onIncrement] never fires.
  final bool canIncrement;

  /// When false the minus button is disabled and [onDecrement] never fires.
  final bool canDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            semanticLabel: l10n.stepperDecrease,
            enabled: canDecrement,
            onTap: onDecrement,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36),
            child: Text(value, textAlign: TextAlign.center, style: valueStyle),
          ),
          _StepButton(
            icon: Icons.add,
            semanticLabel: l10n.stepperIncrease,
            enabled: canIncrement,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;

  /// Screen-reader label announcing the action (localized by the caller).
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.3);

    // InkResponse with radius 24 yields a 48x48 logical tap target around the
    // small glyph, satisfying the >=48dp hit-area guideline while keeping the
    // compact ± visual. Semantics announces the localized action.
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        containedInkWell: false,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon, size: 18, color: color)),
        ),
      ),
    );
  }
}
