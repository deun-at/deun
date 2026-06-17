import 'package:flutter/material.dart';

import 'package:deun/constants.dart';

/// One option in an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A generic segmented control: a field-fill track holding N equal-width
/// options with a raised card indicator behind the selected one.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  /// Currently selected value.
  final T value;

  /// Options, in display order.
  final List<AppSegment<T>> segments;

  /// Called with a segment's value when it is tapped.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment<T>(
                segment: segment,
                selected: segment.value == value,
                labelStyle: labelStyle,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.labelStyle,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool selected;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colorScheme.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? kSoftCardShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (segment.icon != null) ...[
              Icon(segment.icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              segment.label,
              style: labelStyle?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
