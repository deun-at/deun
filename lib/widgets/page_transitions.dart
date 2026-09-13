/// Home-tab switch motion for the go_router stateful shell.
///
/// Part of the Deun v3 motion layer (ANIMATIONS §1).
///
/// Full-screen drill-down routes deliberately have **no** helper here: they
/// return a plain `MaterialPage`, so the transition comes from
/// `PageTransitionsTheme` in `theme_builder.dart`.  On Android that is
/// `PredictiveBackPageTransitionsBuilder` — the back-drag shrinks the page
/// toward the edge, and a button pop or forward push falls back to
/// `FadeForwardsPageTransitionsBuilder`.  Routing transitions through the
/// theme is what makes every drill-down in the app move the same way; a
/// `CustomTransitionPage` supplies its own `transitionsBuilder` and bypasses
/// the theme entirely, which is how predictive back was silently lost between
/// 2026-06-25 and this change.
///
/// Sheets keep their own motion (`ModalBottomSheetPage`), and shell-top tabs
/// use [TabSwitchTransition] below — neither should drill.
library;

import 'package:deun/widgets/motion.dart';
import 'package:flutter/material.dart';

/// The vertical distance (px) the incoming home-tab view travels while fading
/// in, per ANIMATIONS §1 (`translateY(8px)`).
const double kTabSwitchOffset = 8.0;

/// Plays the home-tab-switch motion (ANIMATIONS §1) whenever [index] changes.
///
/// The incoming view fades in while translating up from [kTabSwitchOffset] to
/// rest over [Motion.tabSwitch] (0.26 s) with a [Curves.ease] curve — a gentle
/// fade-up, **no horizontal slide**.
///
/// This widget *wraps* [child] (the `StatefulNavigationShell` / indexed stack);
/// it never rebuilds or replaces it, so all branch state (scroll offsets,
/// nested navigation) is preserved exactly as before. The animation only
/// re-runs when [index] changes, not on every rebuild.
///
/// **Reduced motion:** when `MediaQuery.of(context).disableAnimations` is
/// `true`, [child] is returned directly with no animation.
class TabSwitchTransition extends StatefulWidget {
  const TabSwitchTransition({
    super.key,
    required this.index,
    required this.child,
  });

  /// The current branch index of the shell. A change re-runs the fade-up.
  final int index;

  /// The shell body to wrap (kept alive across switches).
  final Widget child;

  @override
  State<TabSwitchTransition> createState() => _TabSwitchTransitionState();
}

class _TabSwitchTransitionState extends State<TabSwitchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.tabSwitch,
    value: 1.0, // start settled — no entrance animation on first build
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.ease,
  );

  @override
  void didUpdateWidget(TabSwitchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * kTabSwitchOffset),
            child: child,
          ),
        );
      },
    );
  }
}
