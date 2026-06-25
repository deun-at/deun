/// Motion constants for the Deun v3 animation layer.
///
/// All curves and durations are transcribed verbatim from
/// `docs/design_handoff_updated/ANIMATIONS.md`.  Import this file once;
/// never inline magic cubic-bezier values or millisecond literals in
/// feature code.
///
/// Usage:
/// ```dart
/// AnimationController(vsync: this, duration: Motion.screenForward)
///   ..drive(CurveTween(curve: Motion.screenPush));
///
/// // Respect reduced-motion:
/// final dur = reducedIfNeeded(
///   Motion.listItem,
///   reduceMotion: MediaQuery.of(context).disableAnimations,
/// );
/// ```
library;

import 'package:flutter/animation.dart';

/// Named animation curves and durations for the Deun v3 motion layer.
///
/// All [Cubic] control points match the prototype's CSS `cubic-bezier(…)`
/// table in `ANIMATIONS.md`.  Static constants only — no runtime state.
abstract final class Motion {
  // -------------------------------------------------------------------------
  // Curves
  // -------------------------------------------------------------------------

  /// Screen push / list-item rise.
  /// CSS: `cubic-bezier(0.2, 0.8, 0.2, 1)`.
  static const Cubic screenPush = Cubic(0.2, 0.8, 0.2, 1);

  /// Bar grow / fill grow.
  /// CSS: `cubic-bezier(0.2, 0.85, 0.2, 1)`.
  static const Cubic barGrow = Cubic(0.2, 0.85, 0.2, 1);

  /// Bottom-sheet rise.
  /// CSS: `cubic-bezier(0.22, 1, 0.36, 1)`.
  static const Cubic sheetRise = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Success-badge pop (overshoot).
  /// CSS: `cubic-bezier(0.2, 0.9, 0.3, 1.2)`.
  static const Cubic successPop = Cubic(0.2, 0.9, 0.3, 1.2);

  /// Tab-pill slide (springy overshoot).
  /// CSS: `cubic-bezier(0.34, 1.4, 0.5, 1)`.
  static const Cubic tabPill = Cubic(0.34, 1.4, 0.5, 1);

  // -------------------------------------------------------------------------
  // Durations — §1 Screen transitions
  // -------------------------------------------------------------------------

  /// Forward / back screen transition.  Also used for [screenPush].
  static const Duration screenForward = Duration(milliseconds: 360);

  /// Home-tab switch (vertical fade-up, no X slide).
  static const Duration tabSwitch = Duration(milliseconds: 260);

  // -------------------------------------------------------------------------
  // Durations — §2 Staggered list entrance
  // -------------------------------------------------------------------------

  /// Per-item entrance animation duration.
  static const Duration listItem = Duration(milliseconds: 440);

  /// Stagger step between consecutive list items.
  static const Duration listStagger = Duration(milliseconds: 50);

  /// Maximum (cap) delay applied from the 8th item onward.
  static const Duration listStaggerCap = Duration(milliseconds: 380);

  // -------------------------------------------------------------------------
  // Durations — §3 Count-up numbers
  // -------------------------------------------------------------------------

  /// Count-up tween duration (big amount hero widgets).
  static const Duration countUp = Duration(milliseconds: 750);

  // -------------------------------------------------------------------------
  // Durations — §4 Success pop + ring
  // -------------------------------------------------------------------------

  /// Check-badge scale-pop duration.
  static const Duration successPopDuration = Duration(milliseconds: 500);

  /// Expanding ring fade duration.
  static const Duration successRing = Duration(milliseconds: 850);

  /// Delay before the ring starts expanding.
  static const Duration successRingDelay = Duration(milliseconds: 100);

  // -------------------------------------------------------------------------
  // Durations — §5 Charts & progress grow
  // -------------------------------------------------------------------------

  /// Bar (scaleY) grow duration.
  static const Duration barGrowDuration = Duration(milliseconds: 620);

  /// Fill / progress-bar (scaleX) grow duration.
  static const Duration fillGrow = Duration(milliseconds: 720);

  /// Delay before fill grow starts.
  static const Duration fillGrowDelay = Duration(milliseconds: 100);

  // -------------------------------------------------------------------------
  // Durations — §6 Sheet rise / scrim
  // -------------------------------------------------------------------------

  /// Bottom-sheet rise duration.
  static const Duration sheetRiseDuration = Duration(milliseconds: 280);

  /// Scrim fade duration (behind modal sheets).
  static const Duration scrimFade = Duration(milliseconds: 200);

  // -------------------------------------------------------------------------
  // Durations — §7 Looping / ambient
  // -------------------------------------------------------------------------

  /// Scan-line sweep loop period (receipt / QR scanner).
  static const Duration scanSweep = Duration(milliseconds: 2400);

  /// Live-presence dot pulse loop period.
  static const Duration presencePulse = Duration(milliseconds: 1600);

  /// Dark-mode theme-flip crossfade.
  static const Duration darkModeFlip = Duration(milliseconds: 280);
}

// ---------------------------------------------------------------------------
// Reduced-motion helper
// ---------------------------------------------------------------------------

/// Returns [Duration.zero] when [reduceMotion] is `true`, otherwise returns
/// [base] unchanged.
///
/// Pass `MediaQuery.of(context).disableAnimations` as [reduceMotion].
/// The function is intentionally free of [BuildContext] so it can be tested
/// without a widget tree.
///
/// ```dart
/// final dur = reducedIfNeeded(
///   Motion.listItem,
///   reduceMotion: MediaQuery.of(context).disableAnimations,
/// );
/// ```
Duration reducedIfNeeded(Duration base, {required bool reduceMotion}) =>
    reduceMotion ? Duration.zero : base;
