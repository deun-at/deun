import 'package:flutter/material.dart';

/// A full-width dashed-border "ghost" button (v3 handoff: the itemized
/// "Add item by hand" affordance below the item cards).
///
/// A transparent-fill button with a dashed rounded-rectangle outline and a
/// leading icon — the low-emphasis "add another" counterpart to
/// [PrimaryButton]/[SecondaryButton]. Not a Material tonal/filled button.
///
/// - Fill: transparent (ghost).
/// - Border: dashed, 1.4px, drawn in a muted stroke tone. Defaults to
///   [ColorScheme.outline]; pass [color] to tint it (e.g. primary).
/// - Icon + label: same muted tone, [TextTheme.bodyLarge] at w600.
/// - Geometry: radius 15, vertical padding 14, full-width by default — matches
///   the sibling restyle buttons so it lines up under the cards.
/// - Press feedback: subtle [AnimatedScale] to 0.98 (no heavy ripple).
class DashedGhostButton extends StatefulWidget {
  const DashedGhostButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.add,
    this.color,
    this.fullWidth = true,
  });

  /// Callback fired on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label text.
  final String label;

  /// Leading icon shown to the left of the label. Defaults to [Icons.add].
  final IconData icon;

  /// Stroke / foreground tone. Defaults to [ColorScheme.outline] (a muted
  /// hairline). Pass [ColorScheme.primary] for an accent ghost.
  final Color? color;

  /// When `true` (the default), the button expands to fill its parent's width.
  final bool fullWidth;

  @override
  State<DashedGhostButton> createState() => _DashedGhostButtonState();
}

class _DashedGhostButtonState extends State<DashedGhostButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _handleTapDown(TapDownDetails _) {
    if (_enabled) setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (_pressed) setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final tone = (widget.color ?? colorScheme.outline)
        .withValues(alpha: _enabled ? 1.0 : 0.5);

    final labelStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      color: tone,
    );

    final inner = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: tone, radius: 15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: tone),
              const SizedBox(width: 8),
              Text(widget.label, style: labelStyle),
            ],
          ),
        ),
      ),
    );

    final button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _enabled ? widget.onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: inner,
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Paints a dashed rounded-rectangle border in [color]. Same dash/gap loop as
/// the claim-page "take one" chip, generalized to an arbitrary corner radius.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
