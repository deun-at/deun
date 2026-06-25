/// Animated success badge — check-pop + expanding/fading ring (ANIMATIONS §4).
///
/// The badge animates once on mount:
/// - The icon **pops** from scale 0 → 1 over [Motion.successPopDuration] with
///   the [Motion.successPop] overshoot curve.
/// - A translucent bordered circle **expands and fades** from scale 0.55 → 2.4
///   / opacity 0.55 → 0 over [Motion.successRing], starting after
///   [Motion.successRingDelay].
///
/// With [MediaQuery.disableAnimations] the icon is rendered statically at full
/// scale and the ring is omitted entirely.
library;

import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

/// A reusable animated success badge with a check-pop and ring animation.
///
/// Defaults:
/// - [icon]: [Icons.check_circle]
/// - [size]: 56
/// - [color]: [SemanticColors.success] from the ambient theme
class SuccessBadge extends StatefulWidget {
  const SuccessBadge({
    super.key,
    this.icon = Icons.check_circle,
    this.size = 56,
    this.color,
  });

  /// The icon to render inside the badge.
  final IconData icon;

  /// The icon/ring size in logical pixels.
  final double size;

  /// Icon and ring stroke color. Defaults to [SemanticColors.success].
  final Color? color;

  @override
  State<SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Motion.successRing + Motion.successRingDelay,
    );

    // Icon pop: 0 → 1 over the pop window, using the overshoot curve.
    // The pop fits inside the total ring+delay window.
    final popEnd =
        Motion.successPopDuration.inMilliseconds /
        (_controller.duration!.inMilliseconds);
    _iconScale = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, popEnd, curve: Motion.successPop),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final color =
        widget.color ??
        Theme.of(context).extension<SemanticColors>()!.success;

    if (reduceMotion) {
      // Static render — no animation, no ring.
      return Icon(widget.icon, size: widget.size, color: color);
    }

    // Ring animation intervals, relative to the total controller duration.
    final totalMs = _controller.duration!.inMilliseconds.toDouble();
    final ringDelayFraction = Motion.successRingDelay.inMilliseconds / totalMs;

    // Ring scale: 0.55 → 2.4, starting after the delay.
    final ringScale = Tween<double>(begin: 0.55, end: 2.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(ringDelayFraction, 1.0, curve: Curves.easeOut),
      ),
    );

    // Ring opacity: 0.55 → 0, same interval.
    final ringOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(ringDelayFraction, 1.0, curve: Curves.easeOut),
      ),
    );

    return SizedBox(
      width: widget.size * 2.6, // give the ring space to expand
      height: widget.size * 2.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring: expanding bordered circle behind the icon.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: ringOpacity.value,
                child: Transform.scale(
                  scale: ringScale.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2.5),
                    ),
                  ),
                ),
              );
            },
          ),
          // Icon: scale-pop.
          ScaleTransition(
            scale: _iconScale,
            child: Icon(widget.icon, size: widget.size, color: color),
          ),
        ],
      ),
    );
  }
}
