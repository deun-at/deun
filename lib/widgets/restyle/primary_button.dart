import 'package:flutter/material.dart';

/// The v3 primary CTA button (COMPONENTS §1).
///
/// A full-width accent-filled button with a colored soft drop-shadow and a
/// 15-radius rectangle — NOT a Material stadium / tonal button.
///
/// - Background: [ColorScheme.primary] (#5750E6 in the brand seed).
/// - Text: [ColorScheme.onPrimary], [TextTheme.bodyLarge] at w700.
/// - Shadow: `0 12 22 -10 primary.withValues(alpha:0.5)` in light;
///   softened to `alpha:0.25` in dark (a saturated drop-shadow reads poorly
///   on dark surfaces — lower alpha keeps depth without harshness).
/// - Disabled: fill → `primary.withValues(alpha:0.4)`, no shadow.
/// - Press feedback: a subtle [AnimatedScale] to 0.98 on press (no heavy ripple).
/// - Geometry: radius 15, vertical padding 15, full-width by default (≥50 dp tall).
///
/// Usage:
/// ```dart
/// PrimaryButton(
///   label: l10n.save,
///   onPressed: _isBusy ? null : _submit,
///   icon: Icons.ios_share, // optional leading icon
/// )
/// ```
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.fullWidth = true,
    this.loading = false,
  });

  /// Callback fired on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label text.
  final String label;

  /// Optional leading icon shown to the left of the label.
  final IconData? icon;

  /// When `true` (the default), the button expands to fill its parent's width.
  final bool fullWidth;

  /// When `true`, a small spinner replaces the label and the button is
  /// disabled. Allows the caller to show in-progress state without managing
  /// `onPressed: null` separately.
  final bool loading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors
    final bgColor = _enabled
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.4);

    final fgColor = colorScheme.onPrimary.withValues(alpha: _enabled ? 1.0 : 0.6);

    // Shadow: colored in light; softened in dark; omitted when disabled.
    // Dark choice: lower alpha (0.25 vs 0.5) — a saturated purple drop-shadow
    // bleeds heavily on near-black surfaces and reads as glow rather than depth.
    final List<BoxShadow> shadows = _enabled
        ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.5),
              offset: const Offset(0, 12),
              blurRadius: 22,
              spreadRadius: -10,
            ),
          ]
        : const [];

    final labelStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
      color: fgColor,
    );

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.onPrimary,
        ),
      );
    } else if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Text(widget.label, style: labelStyle),
        ],
      );
    } else {
      content = Text(widget.label, style: labelStyle);
    }

    final inner = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: shadows,
        ),
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Center(child: content),
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

/// The v3 secondary button (COMPONENTS §"Secondary / social buttons").
///
/// A white-filled, hairline-bordered counterpart to [PrimaryButton], used as the
/// low-emphasis option in a two-button row (e.g. Copy alongside a primary Share).
///
/// - Background: [ColorScheme.surfaceContainerLowest] (the card-white surface).
/// - Border: 1.5px [ColorScheme.outlineVariant] — the warm hairline token
///   (~#E4E1D8 in light) the spec calls for; flips to the dark hairline in dark
///   mode so the outline stays legible without an inline hex.
/// - Text/icon: [ColorScheme.onSurface] (label) / [ColorScheme.onSurfaceVariant]
///   (icon), [TextTheme.bodyLarge] at w700.
/// - Geometry: radius 15, vertical padding 15, full-width by default (≥50 dp
///   tall) — matches [PrimaryButton] so the two sit flush in a row.
/// - Press feedback: the same subtle [AnimatedScale] to 0.98 (no heavy ripple).
///
/// Labels are kept to a single line ([Text.maxLines] == 1, no wrap) so localized
/// strings like "Link kopieren" don't break across two lines in a tight row.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.fullWidth = true,
  });

  /// Callback fired on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label text.
  final String label;

  /// Optional leading icon shown to the left of the label.
  final IconData? icon;

  /// When `true` (the default), the button expands to fill its parent's width.
  final bool fullWidth;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
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

    final opacity = _enabled ? 1.0 : 0.5;
    final bgColor = colorScheme.surfaceContainerLowest;
    final borderColor = colorScheme.outlineVariant.withValues(alpha: opacity);
    final fgColor = colorScheme.onSurface.withValues(alpha: opacity);
    final iconColor = colorScheme.onSurfaceVariant.withValues(alpha: opacity);

    final labelStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
      color: fgColor,
    );

    final Widget label = Text(
      widget.label,
      style: labelStyle,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    Widget content;
    if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      );
    } else {
      content = label;
    }

    final inner = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        child: Center(child: content),
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
