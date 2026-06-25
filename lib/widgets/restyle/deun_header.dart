import 'package:flutter/material.dart';

/// Custom app-header widget that replaces Material [AppBar] on sub-screens.
///
/// Renders a header with:
///   - A leading 38×38 icon button (or spacer when [showLeading] is false)
///   - A title (+ optional subtitle) **optically centered across the full
///     header width** using a [Stack], so centering is robust regardless of
///     how wide the trailing slot is.
///   - A trailing slot: either a single [trailing] widget (38×38) or a list
///     of [trailingActions] rendered as a compact [Row]. When neither is
///     provided, a 38×38 spacer preserves optical centering.
///
/// [trailing] and [trailingActions] are mutually exclusive. When both are
/// provided, [trailingActions] takes precedence.
///
/// Wrapped in a [SafeArea] (bottom: false) so screens can drop it at the
/// very top of their body without worrying about the status-bar inset.
///
/// Token mapping (light / dark):
/// - Title: `bodyLarge` (16px Hanken) + w700 → `colorScheme.onSurface`
/// - Subtitle: `bodySmall` (≈11.5px) → `colorScheme.onSurfaceVariant`
/// - Icon-button circle bg: `colorScheme.onSurface.withValues(alpha: 0.04)`
///   → faint warm tint on light, faint light tint on dark (correct in both).
/// - Icon color: `colorScheme.onSurface`
/// - Header background: transparent (sits on screen background).
class DeunHeader extends StatelessWidget {
  const DeunHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleLeading,
    this.leadingIcon = Icons.arrow_back,
    this.onLeading,
    this.showLeading = true,
    this.trailing,
    this.trailingActions,
  });

  /// Primary title text. Hanken 16/w700, centered.
  final String title;

  /// Optional subtitle rendered below the title at bodySmall size.
  final String? subtitle;

  /// Optional widget rendered immediately before the subtitle text in a
  /// centered [Row]. Intended for small ambient indicators such as a
  /// live-presence pulse dot. When null, the subtitle renders as a plain
  /// [Text] exactly as before (no change to existing layout).
  final Widget? subtitleLeading;

  /// Icon for the leading button. Defaults to [Icons.arrow_back]; pass
  /// [Icons.close] for modal-style full-screen forms.
  final IconData leadingIcon;

  /// Callback for the leading button. Defaults to [Navigator.maybePop].
  final VoidCallback? onLeading;

  /// When false, no leading button is shown and a 38×38 spacer is used
  /// instead (rare — used when there is no back destination).
  final bool showLeading;

  /// Optional single 38×38 trailing action widget. When null, a 38×38 spacer
  /// preserves optical centering of the title.
  ///
  /// Mutually exclusive with [trailingActions]. When both are provided,
  /// [trailingActions] takes precedence.
  final Widget? trailing;

  /// Optional list of trailing action widgets rendered as a compact [Row].
  /// Use this when you need more than one trailing action (e.g. edit + delete).
  ///
  /// Mutually exclusive with [trailing]. When both are provided, this takes
  /// precedence over [trailing].
  final List<Widget>? trailingActions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    );
    final subtitleStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    Widget leadingSlot;
    if (showLeading) {
      leadingSlot = _HeaderIconButton(
        icon: leadingIcon,
        onTap: onLeading ?? () => Navigator.of(context).maybePop(),
      );
    } else {
      leadingSlot = const SizedBox(width: 38, height: 38);
    }

    // Build the trailing slot.
    // trailingActions takes precedence over trailing.
    Widget trailingSlot;
    if (trailingActions != null && trailingActions!.isNotEmpty) {
      trailingSlot = Row(
        mainAxisSize: MainAxisSize.min,
        children: trailingActions!,
      );
    } else if (trailing != null) {
      trailingSlot = SizedBox(width: 38, height: 38, child: trailing);
    } else {
      trailingSlot = const SizedBox(width: 38, height: 38);
    }

    // The title block is centered across the FULL header width using a Stack.
    // Leading and trailing are pinned to left/right; the title sits in the
    // center layer and spans the full width with overflow ellipsis.
    final subtitleWidget = subtitle != null
        ? (subtitleLeading != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  subtitleLeading!,
                  const SizedBox(width: 8),
                  Text(
                    subtitle!,
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Text(
                subtitle!,
                style: subtitleStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ))
        : null;

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: titleStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ?subtitleWidget,
      ],
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Title centred across the full row width.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: titleBlock,
            ),
            // Leading pinned to the left.
            Align(
              alignment: Alignment.centerLeft,
              child: leadingSlot,
            ),
            // Trailing pinned to the right.
            Align(
              alignment: Alignment.centerRight,
              child: trailingSlot,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal 38×38 circular icon button with a ≥48dp hit target.
///
/// The visible circle (38dp) carries the faint warm-tint background; the
/// [InkWell] is padded to 48dp so the real tap target satisfies accessibility
/// guidelines.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = colorScheme.onSurface.withValues(alpha: 0.04);

    // Outer padding inflates the hit target to ≥48dp while keeping the
    // visible circle at 38dp.
    const double visibleSize = 38;
    const double hitTarget = 48;
    const double pad = (hitTarget - visibleSize) / 2;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(pad),
        child: Container(
          width: visibleSize,
          height: visibleSize,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
