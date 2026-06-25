import 'package:flutter/material.dart';

import '../motion.dart';

/// One destination item for [AppBottomNav].
///
/// [label] must be already-localised — the widget itself does NOT call
/// AppLocalizations so it remains test-harness-light.
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  /// Icon shown when this tab is inactive.
  final IconData icon;

  /// Icon shown when this tab is active.
  final IconData selectedIcon;

  /// Already-localised label string.
  final String label;

  /// When > 0, a [Badge] is shown on the icon.  Pass 0 for no badge.
  final int badgeCount;
}

/// Custom bottom navigation bar with a springy sliding accent-tint pill.
///
/// Design source: `ANIMATIONS.md §6 "Tab bar indicator — sliding pill"`.
///
/// All colours come from [ColorScheme] theme tokens:
/// - Pill fill:          `colorScheme.primaryContainer`
/// - Active icon/label:  `colorScheme.primary`
/// - Inactive icon/label:`colorScheme.onSurfaceVariant`
/// - Bar background:     `colorScheme.surfaceContainerLow`
/// - Top hairline:       `colorScheme.outlineVariant`
///
/// Geometry constants (52×34 pill, 78px bar, 10px label) are layout values
/// from the spec and are safe as literals.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  // Spec geometry constants
  static const double _barHeight = 78;
  static const double _pillWidth = 52;
  static const double _pillHeight = 34;
  static const double _labelSize = 10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pillDuration = reducedIfNeeded(Motion.tabPillSlide, reduceMotion: reduceMotion);

    return Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      // LayoutBuilder gives us the real bar width so we can compute the pill
      // position; the Stack then correctly hosts both Positioned and non-
      // Positioned children.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / items.length;
          final pillLeft = slotWidth * selectedIndex + (slotWidth - _pillWidth) / 2;
          const pillTop = (_barHeight - _pillHeight) / 2;

          return Stack(
            children: [
              // Sliding pill — animated Positioned inside a Stack is valid here.
              AnimatedPositioned(
                duration: pillDuration,
                curve: Motion.tabPill,
                left: pillLeft,
                top: pillTop,
                width: _pillWidth,
                height: _pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(_pillHeight / 2),
                  ),
                ),
              ),
              // Tap targets row (on top of pill)
              Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavTab(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelect(i),
                        activeColor: colorScheme.primary,
                        inactiveColor: colorScheme.onSurfaceVariant,
                        labelSize: _labelSize,
                        barHeight: _barHeight,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual tab
// ---------------------------------------------------------------------------

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.labelSize,
    required this.barHeight,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final double labelSize;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    final iconData = selected ? item.selectedIcon : item.icon;

    Widget iconWidget = Icon(iconData, color: color, size: 24);

    if (item.badgeCount > 0) {
      iconWidget = Badge(
        label: Text('${item.badgeCount}'),
        child: iconWidget,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
