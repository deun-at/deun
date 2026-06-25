import 'package:flutter/material.dart';

import 'package:deun/constants.dart';

/// The base list-card container: a card-surface ([ColorScheme.surfaceContainerLowest])
/// rounded rectangle with the soft spec card shadow.
///
/// In dark mode the light-tinted card shadow is dropped (a near-black shadow on
/// a dark surface only muddies it); the lighter card surface carries the
/// elevation instead.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Optional override for the card surface color.
  final Color? color;

  /// Optional tap handler; when set the card becomes an ink-splashing button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainerLowest,
        borderRadius: radius,
        // Spec card shadow: 0 2px 4px rgba(20,18,12,.04). Omitted in dark.
        boxShadow: isDark ? null : kSoftCardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      ),
    );
  }
}
