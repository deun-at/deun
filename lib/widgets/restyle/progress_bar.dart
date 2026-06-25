import 'dart:async';

import 'package:deun/widgets/motion.dart';
import 'package:flutter/material.dart';

/// A rounded progress bar: a field-fill track with a primary (or custom) fill.
/// [value] is clamped to 0..1 — read [clampedValue] for the effective fraction.
///
/// By default the fill grows from 0 → [clampedValue] on first mount using
/// [Motion.fillGrow] (720 ms) with a [Motion.fillGrowDelay] (100 ms) delay and
/// the [Motion.barGrow] curve, origin [Alignment.centerLeft].
///
/// Respects `MediaQuery.disableAnimations`; when set the fill renders at its
/// final width immediately without running any controller.
///
/// On [didUpdateWidget] with a changed [value] the bar re-animates smoothly
/// from its current factor to the new [clampedValue].
class ProgressBar extends StatefulWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.fillColor,
    this.trackColor,
    this.borderRadius,
  });

  /// Desired fill fraction; clamped to 0..1 at render time.
  final double value;

  final double height;

  /// Fill color; defaults to the theme primary.
  final Color? fillColor;

  /// Track color; defaults to a field-fill surface.
  final Color? trackColor;

  /// Corner radius; defaults to a fully-rounded bar (height / 2).
  final double? borderRadius;

  /// [value] clamped into the valid 0..1 range.
  double get clampedValue => value.clamp(0.0, 1.0).toDouble();

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;

  // Tracks the fill factor at which the last animation started, so that
  // mid-animation value changes re-grow smoothly from the current position.
  double _fromFactor = 0.0;
  double _toFactor = 0.0;

  bool get _reducedMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _toFactor = widget.clampedValue;

    _controller = AnimationController(
      vsync: this,
      duration: Motion.fillGrow,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Motion.barGrow);

    // Kick off the entrance grow after first frame is rendered so that
    // MediaQuery is available, then delay by fillGrowDelay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reducedMotion) return; // reduced-motion: stays at 0 until build() sets it
      _delayTimer = Timer(Motion.fillGrowDelay, () {
        if (mounted) _controller.forward();
      });
    });
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;

    // Capture the current rendered factor as the new start point.
    _fromFactor = _currentFactor;
    _toFactor = widget.clampedValue;

    // Reset and re-play.
    _controller.reset();
    _controller.forward();
  }

  /// The fill factor currently rendered (interpolating between [_fromFactor]
  /// and [_toFactor] as the controller progresses).
  double get _currentFactor => _fromFactor + (_toFactor - _fromFactor) * _animation.value;

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.borderRadius ?? widget.height / 2);

    // Reduced-motion: skip animation entirely, render at final value.
    if (_reducedMotion) {
      return _buildBar(
        widthFactor: widget.clampedValue,
        colorScheme: colorScheme,
        radius: radius,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => _buildBar(
        widthFactor: _currentFactor,
        colorScheme: colorScheme,
        radius: radius,
      ),
    );
  }

  Widget _buildBar({
    required double widthFactor,
    required ColorScheme colorScheme,
    required BorderRadius radius,
  }) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: widget.height,
        color: widget.trackColor ?? colorScheme.surfaceContainerHigh,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(color: widget.fillColor ?? colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
