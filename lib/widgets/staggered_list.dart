/// Shared helper for the v3 staggered list entrance (ANIMATIONS §2).
///
/// Usage:
/// ```dart
/// AnimationLimiter(
///   child: ListView(
///     children: staggeredChildren(context, myChildren),
///   ),
/// )
/// ```
/// Or use the convenience wrapper that checks reduced motion for you:
/// ```dart
/// staggeredListView(
///   context: context,
///   listViewBuilder: (children) => ListView(children: children),
///   children: myChildren,
/// )
/// ```
library;

import 'package:deun/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Wraps [children] with [AnimationConfiguration.toStaggeredList] using the
/// Motion constants.
///
/// Returns plain [children] unchanged when [disableAnimations] is true
/// (reduced-motion system preference).
List<Widget> staggeredChildren(
  BuildContext context,
  List<Widget> children,
) {
  if (MediaQuery.of(context).disableAnimations) {
    return children;
  }
  return AnimationConfiguration.toStaggeredList(
    duration: Motion.listItem,
    childAnimationBuilder: (widget) => SlideAnimation(
      verticalOffset: 12,
      curve: Motion.screenPush,
      child: FadeInAnimation(
        curve: Motion.screenPush,
        child: widget,
      ),
    ),
    children: children,
  );
}
