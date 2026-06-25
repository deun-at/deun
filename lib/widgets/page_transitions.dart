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
