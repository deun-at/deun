import 'package:flutter/material.dart';

/// A small, strong section header (e.g. "Your groups") in the secondary text
/// color, with an optional [trailing] action slot (e.g. a "New" button).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing, this.emphasized = false});

  final String label;

  /// Optional trailing widget aligned to the end of the row.
  final Widget? trailing;

  /// When true, render the larger 18px/w700 header tier (titleLarge) the v3
  /// handoff uses for the "Your groups" home section — versus the default
  /// small caption-style label used for the many minor section headers.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = emphasized
        ? textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700)
        : textTheme.titleSmall?.copyWith(
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
