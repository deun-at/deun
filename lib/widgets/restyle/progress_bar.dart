import 'package:flutter/material.dart';

/// A rounded progress bar: a field-fill track with a primary (or custom) fill.
/// [value] is clamped to 0..1 — read [clampedValue] for the effective fraction.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.fillColor,
    this.trackColor,
    this.borderRadius,
  });

  /// Desired fill fraction; clamped to 0..1 at render time.
  final double value;

  final double height;

  /// Fill color; defaults to the theme primary.
  final Color? fillColor;

  /// Track color; defaults to a field-fill surface.
  final Color? trackColor;

  /// Corner radius; defaults to a fully-rounded bar (height / 2).
  final double? borderRadius;

  /// [value] clamped into the valid 0..1 range.
  double get clampedValue => value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius ?? height / 2);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: trackColor ?? colorScheme.surfaceContainerHigh,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clampedValue,
            child: Container(color: fillColor ?? colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
