/// Shared-axis page transition helper for go_router drill-down routes.
///
/// Part of the Deun v3 motion layer (ANIMATIONS §1).  Import this file and
/// call [sharedAxisPage] inside `pageBuilder:` on any full-screen push/pop
/// route to get the horizontal shared-axis transition with the correct 360 ms
/// duration from [Motion.screenForward].
///
/// Sheets and shell-top tabs must NOT use this helper — they have their own
/// motion semantics.
library;

import 'package:animations/animations.dart';
import 'package:deun/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Returns a [CustomTransitionPage] that plays a Material shared-axis
/// transition (horizontal axis by default) on forward push and reverse pop.
///
/// - [key] should be `state.pageKey` from the go_router `pageBuilder` callback.
/// - [child] is the destination screen widget.
/// - [type] defaults to [SharedAxisTransitionType.horizontal] for standard
///   push/pop drill-downs.
///
/// **Reduced motion:** when `MediaQuery.of(context).disableAnimations` is
/// `true`, the [transitionsBuilder] returns [child] directly (no slide,
/// instant appearance) — both [transitionDuration] and
/// [reverseTransitionDuration] remain 360 ms so the route itself is still
/// popped cleanly; only the visual animation is skipped.
CustomTransitionPage<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: Motion.screenForward,
    reverseTransitionDuration: Motion.screenForward,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return child;
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

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
