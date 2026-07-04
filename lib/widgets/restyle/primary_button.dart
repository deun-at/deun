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
    this.compact = false,
    this.background,
    this.foreground,
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

  /// Compact variant: a smaller inline pill (StadiumBorder, tighter padding,
  /// no drop-shadow, intrinsic width) for list-tile / trailing-row actions.
  /// Implies `fullWidth: false`.
  final bool compact;

  /// Optional fill-color override for contextual treatments — danger
  /// (`colorScheme.error`), on-hero (`onHero`), or ink pills. Must be a theme
  /// token / semantic color, never an inline hex. Defaults to
  /// `colorScheme.primary` when null.
  final Color? background;

  /// Optional label/icon color override, paired with [background] (e.g.
  /// `colorScheme.onError`). Defaults to `colorScheme.onPrimary` when null.
  final Color? foreground;

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

    // Base fill / foreground: caller override (contextual: danger / hero / ink)
    // or the default primary accent.
    final baseBg = widget.background ?? colorScheme.primary;
    final baseFg = widget.foreground ?? colorScheme.onPrimary;

    // Colors
    final bgColor = _enabled ? baseBg : baseBg.withValues(alpha: 0.4);

    final fgColor = baseFg.withValues(alpha: _enabled ? 1.0 : 0.6);

    // Shadow: colored in light; softened in dark; omitted when disabled or
    // compact. The shadow tint tracks the (possibly overridden) fill so a
    // danger/hero button casts a matching glow, not a stray purple one.
    // Dark choice: lower alpha (0.25 vs 0.5) — a saturated drop-shadow bleeds
    // heavily on near-black surfaces and reads as glow rather than depth.
    final List<BoxShadow> shadows = (_enabled && !widget.compact)
        ? [
            BoxShadow(
              color: baseBg.withValues(alpha: isDark ? 0.25 : 0.5),
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

    // Labels stay on a single line and ellipsize so localized strings (e.g.
    // "Begleichen" for "Settle up") don't overflow a tight inline pill —
    // mirrors [SecondaryButton]. Flexible in the icon Row lets the label
    // shrink instead of forcing the Row past its bounds.
    final Widget label = Text(
      widget.label,
      style: labelStyle,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: baseFg,
        ),
      );
    } else if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: fgColor),
          SizedBox(width: widget.compact ? 5 : 8),
          Flexible(child: label),
        ],
      );
    } else {
      content = label;
    }

    // Compact: a tighter stadium pill (COMPONENTS §"Stadium pills") without the
    // colored drop-shadow; default: the full 15-radius CTA with padding 15.
    final inner = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              widget.compact ? BorderRadius.circular(999) : BorderRadius.circular(15),
          boxShadow: shadows,
        ),
        padding: widget.compact
            ? const EdgeInsets.symmetric(vertical: 9, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 15),
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

    if (widget.fullWidth && !widget.compact) {
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
///
/// Social sign-in buttons (Google/GitHub) reuse this shape via [leading] (an
/// untinted brand mark instead of the theme-tinted [icon]) and
/// [alignStart] (left-aligned label per COMPONENTS §"Secondary / social
/// buttons").
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.leading,
    this.alignStart = false,
    this.fullWidth = true,
    this.compact = false,
    this.foreground,
    this.background,
  });

  /// Callback fired on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label text.
  final String label;

  /// Optional leading icon shown to the left of the label, tinted with the
  /// theme's `onSurfaceVariant`. Use [leading] instead for an untinted widget
  /// (e.g. a multicolor brand mark). Ignored when [leading] is set.
  final IconData? icon;

  /// Optional untinted leading widget (e.g. a brand-colored icon) shown to the
  /// left of the label. Takes precedence over [icon] and keeps its own color.
  final Widget? leading;

  /// When `true`, the leading mark + label are left-aligned (social-button
  /// layout). Defaults to centered.
  final bool alignStart;

  /// When `true` (the default), the button expands to fill its parent's width.
  final bool fullWidth;

  /// Compact variant: a smaller inline pill (StadiumBorder, tighter padding,
  /// intrinsic width) for list-tile / trailing-row actions. Implies
  /// `fullWidth: false`.
  final bool compact;

  /// Optional label/icon color override for a contextual tint (e.g.
  /// `colorScheme.error` on a destructive cancel). Must be a theme token,
  /// never an inline hex. Defaults to the standard onSurface pair when null.
  final Color? foreground;

  /// Optional fill override for a neutral tonal variant (e.g.
  /// `colorScheme.surfaceContainer` for the gray "Remind" pill). When set the
  /// hairline border is dropped so it reads as a tonal fill, not an outline.
  /// Must be a theme token, never an inline hex.
  final Color? background;

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
    // A tonal fill override drops the hairline; otherwise the white card
    // surface with an outlineVariant border.
    final bool tonal = widget.background != null;
    final bgColor = widget.background ?? colorScheme.surfaceContainerLowest;
    // A foreground override (e.g. danger) tints border, label AND icon so the
    // whole outlined pill reads in the contextual color.
    final baseFg = widget.foreground ?? colorScheme.onSurface;
    final borderColor =
        (widget.foreground ?? colorScheme.outlineVariant).withValues(alpha: opacity);
    final fgColor = baseFg.withValues(alpha: opacity);
    final iconColor =
        (widget.foreground ?? colorScheme.onSurfaceVariant).withValues(alpha: opacity);

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

    // Brand mark (untinted) takes precedence over the theme-tinted icon.
    final Widget? mark = widget.leading ??
        (widget.icon != null
            ? Icon(widget.icon, size: 18, color: iconColor)
            : null);

    Widget content;
    if (mark != null) {
      content = Row(
        mainAxisSize:
            widget.alignStart ? MainAxisSize.max : MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 9),
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
          borderRadius:
              widget.compact ? BorderRadius.circular(999) : BorderRadius.circular(15),
          border: tonal ? null : Border.all(color: borderColor, width: 1.5),
        ),
        padding: widget.compact
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        child: widget.alignStart
            ? Align(alignment: Alignment.centerLeft, child: content)
            : Center(child: content),
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

    if (widget.fullWidth && !widget.compact) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
