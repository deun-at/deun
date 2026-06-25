import 'package:flutter/material.dart';

/// Custom app-header widget that replaces Material [AppBar] on sub-screens.
///
/// Renders a single 38px-tall flex row with:
///   `[leading 38×38 icon button] · [flex:1 centered title] · [trailing 38×38 action or spacer]`
///
/// The empty 38×38 right spacer keeps the title optically centered when there
/// is no trailing action. Wrapped in a [SafeArea] (bottom: false) so screens
/// can drop it at the very top of their body without worrying about the
/// status-bar inset.
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
    this.leadingIcon = Icons.arrow_back,
    this.onLeading,
    this.showLeading = true,
    this.trailing,
  });

  /// Primary title text. Hanken 16/w700, centered.
  final String title;

  /// Optional subtitle rendered below the title at bodySmall size.
  final String? subtitle;

  /// Icon for the leading button. Defaults to [Icons.arrow_back]; pass
  /// [Icons.close] for modal-style full-screen forms.
  final IconData leadingIcon;

  /// Callback for the leading button. Defaults to [Navigator.maybePop].
  final VoidCallback? onLeading;

  /// When false, no leading button is shown and a 38×38 spacer is used
  /// instead (rare — used when there is no back destination).
  final bool showLeading;

  /// Optional 38×38 trailing action widget. When null, a 38×38 spacer
  /// preserves optical centering of the title.
  final Widget? trailing;

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

    Widget trailingSlot;
    if (trailing != null) {
      trailingSlot = SizedBox(width: 38, height: 38, child: trailing);
    } else {
      trailingSlot = const SizedBox(width: 38, height: 38);
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Row(
          children: [
            leadingSlot,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: titleStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: subtitleStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            trailingSlot,
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
