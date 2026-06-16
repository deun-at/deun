import 'package:flutter/material.dart';

/// A small, strong section header (e.g. "Your groups") in the secondary text
/// color, with an optional [trailing] action slot (e.g. a "New" button).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing});

  final String label;

  /// Optional trailing widget aligned to the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        ?trailing,
      ],
    );
  }
}
