import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/screen_gutter.dart';
import 'package:flutter/material.dart';

/// Identifies the icon chip's own scale animation on an [EmptyState].
///
/// A [PrimaryButton] in the action slot renders a [ScaleTransition] of its own
/// for press feedback, so a test asking "did the chip pop?" has to name this
/// one specifically rather than searching by type. Same device, and same
/// reason, as [kPrimaryButtonCheckPopKey].
const Key kEmptyStateChipPopKey = ValueKey('empty-state-chip-pop');

/// Why a screen is blank.
///
/// [empty] is an account with nothing in it yet; [error] is a load that failed.
/// They must never look the same — rendering the empty copy on a failed fetch
/// tells the user their data is gone when the network merely blinked.
enum EmptyStateTone { empty, error }

/// The one blank-screen component: a tinted icon chip, a headline, optional
/// body copy, and an optional action.
///
/// **This widget owns no scrollable.** Its predecessor (`EmptyListWidget`)
/// wrapped itself in `RefreshIndicator` + `ListView`, which made it unusable
/// inside a screen that already had a list — two nested vertical viewports give
/// unbounded height and crash layout. So there are two entry points and the
/// call site says which it needs:
///
/// - [EmptyState] — a bare [Column] to drop into a caller's own scroll view.
/// - [EmptyState.refreshable] — the same column wrapped in a pull-to-refresh
///   list, for a screen whose empty branch replaces the list entirely.
///
/// The chip scales 0 → 1 once on mount with the [Motion.successPop] overshoot;
/// the words are laid out at rest from the first frame. An empty screen is a
/// message, and fading the message in delays the only thing on screen — but a
/// wholly static screen after a moving transition reads as dead, so the motion
/// is confined to the one element carrying no information.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.headline,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = EmptyStateTone.empty,
  }) : onRefresh = null;

  /// The self-wrapping variant: the same column inside a
  /// [RefreshIndicator] + single always-scrollable [ListView], so the pull
  /// gesture still works on a list with nothing in it.
  const EmptyState.refreshable({
    super.key,
    required Future<void> Function() this.onRefresh,
    required this.icon,
    required this.headline,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = EmptyStateTone.empty,
  });

  /// The glyph shown in the tinted chip.
  final IconData icon;

  /// The one-line statement of what is missing.
  final String headline;

  /// Optional supporting line explaining how to fill the screen. Omit it where
  /// the headline says everything.
  final String? body;

  /// Label of the optional action. Rendered only alongside [onAction].
  final String? actionLabel;

  /// The optional action. Give the screen a CTA only where it has no prominent
  /// affordance of its own — a screen carrying an extended FAB does not need a
  /// third way to do one thing.
  final VoidCallback? onAction;

  /// Whether the screen is blank because it is empty or because a load failed.
  final EmptyStateTone tone;

  /// Non-null only via [EmptyState.refreshable].
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isError = tone == EmptyStateTone.error;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ChipPop(
          icon: icon,
          background: isError
              ? colorScheme.errorContainer
              : colorScheme.primaryContainer,
          foreground: isError
              ? colorScheme.onErrorContainer
              : colorScheme.onPrimaryContainer,
          reduceMotion: MediaQuery.of(context).disableAnimations,
        ),
        const SizedBox(height: 24),
        Text(
          headline,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          // Capped near 30 characters per line: a centred paragraph running the
          // full width of a tablet reads as a wall, not as a hint.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              body!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          PrimaryButton(
            label: actionLabel!,
            onPressed: onAction,
            fullWidth: false,
          ),
        ],
      ],
    );

    // An empty branch sits outside the screen's own scroll view, so it applies
    // the gutter itself — see [kScreenGutter].
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenGutter),
      child: column,
    );

    if (onRefresh == null) return padded;

    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: ListView(
        // Always scrollable: without it a list shorter than its viewport
        // swallows the drag and the refresh never fires.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 100), padded],
      ),
    );
  }
}

/// The chip that carries the empty state's glyph, popping once on mount.
///
/// With reduced motion it is rendered statically at full scale and no
/// [ScaleTransition] is built at all.
class _ChipPop extends StatefulWidget {
  const _ChipPop({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.reduceMotion,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final bool reduceMotion;

  @override
  State<_ChipPop> createState() => _ChipPopState();
}

class _ChipPopState extends State<_ChipPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Built eagerly, not as a lazy `late final` initialiser: under reduced
    // motion nothing else would ever touch the controller, so it would first be
    // constructed inside dispose(), where the ancestor lookup a Ticker needs is
    // no longer safe. Same bug as PrimaryButton._CheckPopState (commit
    // 33c7d2a).
    _controller = AnimationController(
      vsync: this,
      duration: Motion.successPopDuration,
    );
    _scale = _controller.drive(CurveTween(curve: Motion.successPop));
    if (!widget.reduceMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(widget.icon, size: 40, color: widget.foreground),
    );

    if (widget.reduceMotion) return chip;
    return ScaleTransition(
      key: kEmptyStateChipPopKey,
      scale: _scale,
      child: chip,
    );
  }
}
