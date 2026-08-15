import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom app-header widget that replaces Material [AppBar] on sub-screens.
///
/// Renders a header with:
///   - A leading 38×38 icon button (or spacer when [showLeading] is false)
///   - A title (+ optional subtitle) **optically centered across the full
///     header width**, whatever the trailing slot's measured width — unless
///     centering would starve it, in which case it takes the whole band
///     between the slots (see `_titlePadding`).
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

    // The leading slot is DeunHeader's own widget, so its width is exact rather
    // than assumed: a HeaderIconButton is a 48dp hit target, the spacer is 38dp.
    final double leadingSlotWidth = showLeading ? 48 : 38;

    Widget leadingSlot;
    if (showLeading) {
      leadingSlot = HeaderIconButton(
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

    // Leading | title | trailing, with the title laid out in what the two slots
    // leave. The trailing slot is whatever the caller passed, so its width is
    // MEASURED (outer width minus the leading slot minus the band the Row hands
    // the title) rather than guessed at a fixed number of dp per action.
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double headerWidth = constraints.maxWidth;
            return Row(
              children: [
                leadingSlot,
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bandConstraints) {
                      final double bandWidth = bandConstraints.maxWidth;
                      final double trailingWidth = math.max(
                        0,
                        headerWidth - bandWidth - leadingSlotWidth,
                      );
                      return Padding(
                        padding: _titlePadding(
                          headerWidth: headerWidth,
                          leadingWidth: leadingSlotWidth,
                          trailingWidth: trailingWidth,
                        ),
                        // heightFactor: the header sits in an unbounded-height
                        // Column, so the title layer shrink-wraps its child
                        // instead of trying to fill infinity.
                        child: Align(
                          alignment: Alignment.center,
                          heightFactor: 1,
                          child: titleBlock,
                        ),
                      );
                    },
                  ),
                ),
                trailingSlot,
              ],
            );
          },
        ),
      ),
    );
  }

  /// Padding that keeps the title **optically centered across the full header
  /// width** — the band between the slots is off-center whenever they differ, so
  /// the wider side's excess is added back on the narrower side.
  ///
  /// Centering costs the title twice the widest slot: three trailing actions
  /// reserve 3×48dp per side, which leaves ~44dp of title on a 360dp phone. When
  /// centering starves the title like that, it takes the whole band between the
  /// slots instead. It still cannot paint under either slot — it is simply no
  /// longer centered on a row that has no room to center it.
  static EdgeInsets _titlePadding({
    required double headerWidth,
    required double leadingWidth,
    required double trailingWidth,
  }) {
    final double widestSlot = math.max(leadingWidth, trailingWidth);
    final double centeredTitleWidth = headerWidth - 2 * widestSlot;
    if (centeredTitleWidth < _minCenteredTitleWidth) {
      return EdgeInsets.zero;
    }
    return EdgeInsets.only(
      left: math.max(0, trailingWidth - leadingWidth),
      right: math.max(0, leadingWidth - trailingWidth),
    );
  }

  /// Absolute floor (in logical pixels) a centered title must keep before
  /// centering is given up (see [_titlePadding]). This is the same 120dp
  /// readability bar the regression tests assert directly, rather than a
  /// fraction of header width: a proportional test (e.g. 50% of header width)
  /// would also punish ordinary 2-action headers (edit + delete) on narrow
  /// phones even though their centered title comfortably clears 120dp there —
  /// only genuinely cramped layouts (e.g. 3 trailing actions on a 360dp phone,
  /// leaving ~44dp) should give up centering.
  static const double _minCenteredTitleWidth = 120;
}

/// The standard 38×38 circular header-action button (COMPONENTS.md §1 "Icon
/// buttons" / §2 "App headers"), with a ≥48dp hit target.
///
/// The visible circle (38dp) carries the action background; the [InkWell] is
/// padded to 48dp so the real tap target satisfies accessibility guidelines.
///
/// Two variants, both routed through the theme (never inline prototype hex):
///
/// - **Tinted (default)** — faint warm-tint surface
///   `colorScheme.onSurface.withValues(alpha: 0.04)` with an `onSurface` icon.
///   Reads as a faint warm tint on light and a faint light tint on dark, so it
///   is correct in both brightnesses. Used for back/close and secondary
///   actions (e.g. QR).
/// - **Filled accent** ([filled] = true) — `colorScheme.primary` fill (the
///   app's accent indigo, `#5750E6` in the brand seed) with a legible
///   `onPrimary` icon and the v3 colored soft drop-shadow
///   (`0 8 16 -8 primary@0.5`, softened on dark). Used for the primary action
///   in a header (e.g. add-friend).
///
/// Reuse this across custom headers (Friends/Add-friend/QR, etc.) instead of
/// bespoke circles or Material [IconButton]s.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
    this.iconColor,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// When true, renders the filled accent variant (primary fill + onPrimary
  /// icon + colored soft shadow). Otherwise the faint warm-tint variant.
  final bool filled;

  /// Optional tooltip / semantic label for the action.
  final String? tooltip;

  /// Optional override for the icon color, layered on top of the tinted
  /// variant's neutral warm-white circle. Used for semantic actions that keep
  /// the neutral circle but tint only the glyph (e.g. the danger-red logout /
  /// sign-out action). Ignored for the [filled] variant. Pass a theme-resolved
  /// color (e.g. `SemanticColors.danger`) — never inline prototype hex.
  final Color? iconColor;

  /// When true, shows a small spinner in place of [icon] and ignores taps.
  /// For actions that start an async step (e.g. a network probe) before their
  /// visible effect — so a slow response can't be tapped twice and stack a
  /// second effect on top of the first.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = filled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.04);
    // The tinted variant keeps its neutral circle but allows an [iconColor]
    // override for semantic glyphs (e.g. danger-red logout); the filled accent
    // always uses onPrimary for legibility on the primary fill.
    final resolvedIconColor = filled
        ? colorScheme.onPrimary
        : (iconColor ?? colorScheme.onSurface);

    // Filled accent carries the v3 colored soft drop-shadow; softened on dark
    // (a saturated drop-shadow reads as glow on near-black surfaces), matching
    // PrimaryButton.
    final List<BoxShadow> shadows = filled
        ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.5),
              offset: const Offset(0, 8),
              blurRadius: 16,
              spreadRadius: -8,
            ),
          ]
        : const [];

    // Outer padding inflates the hit target to ≥48dp while keeping the
    // visible circle at 38dp.
    const double visibleSize = 38;
    const double hitTarget = 48;
    const double pad = (hitTarget - visibleSize) / 2;

    Widget button = InkWell(
      onTap: loading ? null : onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(pad),
        child: Container(
          width: visibleSize,
          height: visibleSize,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: shadows,
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: resolvedIconColor,
                    ),
                  ),
                )
              : Icon(icon, size: 22, color: resolvedIconColor),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
