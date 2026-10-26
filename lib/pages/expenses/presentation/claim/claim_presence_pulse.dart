import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

/// A small dot that pulses on a ~1.6s loop (Motion spec). Collapses to a static
/// dot when the user has requested reduced motion.
class ClaimPresencePulse extends StatefulWidget {
  const ClaimPresencePulse({super.key});

  @override
  State<ClaimPresencePulse> createState() => _ClaimPresencePulseState();
}

class _ClaimPresencePulseState extends State<ClaimPresencePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.presencePulse,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final color = semantic.success;

    // Start/stop the loop in build so it reacts to a live reduce-motion change.
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    const double dot = 8;
    if (reduceMotion) {
      return Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value; // 0..1
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding, fading halo.
              Container(
                width: dot + (10 * t),
                height: dot + (10 * t),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: (1 - t) * 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}
