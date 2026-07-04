import 'package:flutter/material.dart';

import 'restyle/soft_card.dart';
import 'restyle/spaced_card_list.dart';

/// The skeleton silhouette a [ShimmerCardList] paints while its real content
/// loads. Each shape mirrors the v3 card/row it stands in for so the loading
/// state shares the real layout's rhythm (F145).
enum ShimmerShape {
  /// Group-list card: spaced [SoftCard]s, each a leading rounded icon tile +
  /// title bar, then a footer avatar row + a small balance bar.
  card,

  /// Friend / member / contact / search rows: joined rows in one [SoftCard],
  /// each an avatar circle + name/subtitle bars and a trailing balance bar.
  row,

  /// Plain stacked bars (payment, statistics category rows): a leading dot + a
  /// couple of text bars in one card.
  bars,

  /// Expense-list ledger: day-section cards, each a [SectionLabel]-height header
  /// bar + a [SoftCard] of `_QuickRow` silhouettes (42px rounded icon tile +
  /// title/subtitle bars + trailing total bar). Mirrors the real day-grouped
  /// ledger the shimmer stands in for (F166).
  ledger,
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

class ShimmerCardList extends StatefulWidget {
  const ShimmerCardList({
    super.key,
    required this.height,
    required this.listEntryLength,
    this.shape = ShimmerShape.bars,
  });

  final double height;
  final int listEntryLength;

  /// Which real silhouette this skeleton mirrors (F145). Defaults to plain
  /// [ShimmerShape.bars]; the group list passes [ShimmerShape.card] and the
  /// friend/member/contact rows pass [ShimmerShape.row].
  final ShimmerShape shape;

  @override
  State<StatefulWidget> createState() => ShimmerCardListState();
}

class ShimmerCardListState extends State<ShimmerCardList>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  LinearGradient get gradient {
    ThemeData themeData = Theme.of(context);
    ColorScheme colorScheme = themeData.colorScheme;

    // Translucent base so the bones show THROUGH the ShaderMask (BlendMode.srcATop
    // replaces the painted RGB): an opaque base would overpaint every silhouette
    // into a flat block (F166). Only the sweep highlight is (near-)opaque.
    Color base = Colors.transparent;
    Color shimmerColor = colorScheme.surface.withValues(alpha: 0.6);

    return LinearGradient(
      colors: [
        base,
        shimmerColor,
        base,
      ],
      stops: const [
        0,
        0.2,
        0.3,
      ],
      begin: const Alignment(-1.0, -0.3),
      end: const Alignment(1.0, 0.3),
      transform: _SlidingGradientTransform(slidePercent: _shimmerController.value),
    );
  }

  Listenable get shimmerChanges => _shimmerController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return ShaderMask(
              shaderCallback: (bounds) {
                return gradient.createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: _skeleton(context));
        });
  }

  Widget _skeleton(BuildContext context) {
    switch (widget.shape) {
      case ShimmerShape.card:
        return _CardSkeletonList(count: widget.listEntryLength);
      case ShimmerShape.row:
        return _RowSkeletonList(count: widget.listEntryLength);
      case ShimmerShape.bars:
        return _BarsSkeletonList(
          count: widget.listEntryLength,
          height: widget.height,
        );
      case ShimmerShape.ledger:
        return _LedgerSkeletonList(count: widget.listEntryLength);
    }
  }
}

/// A solid placeholder block filled with the theme's muted skeleton token. The
/// shimmer gradient above (BlendMode.srcATop) is painted over this fill.
class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  final double width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Group-list card skeleton: mirrors [GroupListItem] — a leading rounded icon
/// tile + title bar, then a footer avatar-stack row and a small balance bar,
/// laid out as spaced [SoftCard]s via the SPACED preset (F143).
class _CardSkeletonList extends StatelessWidget {
  const _CardSkeletonList({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Clip-safe inside an Expanded: extra cards clip rather than overflow.
    return _ClipSafe(
      child: SpacedCardList(
        children: List.generate(
          count,
          (_) => const SoftCard(
            padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Bone(width: 40, height: 40, radius: 12),
                    SizedBox(width: 12),
                    _Bone(width: 120, height: 16),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    // Avatar-stack silhouette (four overlapping circles).
                    _AvatarRow(),
                    Spacer(),
                    _Bone(width: 64, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlapping circles standing in for an [AvatarStack].
class _AvatarRow extends StatelessWidget {
  const _AvatarRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26 + 3 * 16,
      height: 26,
      child: Stack(
        children: [
          for (var i = 0; i < 4; i++)
            Positioned(
              left: i * 16.0,
              child: const _Bone(
                width: 26,
                height: 26,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Friend / member / contact / search row skeleton: mirrors the identity row
/// (avatar circle + name/username bars) with a trailing balance bar, joined
/// into one [SoftCard].
class _RowSkeletonList extends StatelessWidget {
  const _RowSkeletonList({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Clip-safe inside an Expanded: extra rows clip rather than overflow.
    // One joined SoftCard (radius 20, v4 padding) — same chrome as the live
    // friend list (F166), not the legacy CardColumn card/margin/28-8 radii.
    return _ClipSafe(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        borderRadius: 20,
        child: Column(
          children: List.generate(
            count,
            (_) => const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  _Bone(width: 40, height: 40, shape: BoxShape.circle),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 110, height: 14),
                        SizedBox(height: 6),
                        _Bone(width: 70, height: 11),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  _Bone(width: 56, height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain stacked-bar skeleton: a leading dot + a text bar per row, joined into
/// one [SoftCard].
class _BarsSkeletonList extends StatelessWidget {
  const _BarsSkeletonList({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Keep bars proportional to the caller's requested row height.
    final barHeight = (height * 0.28).clamp(10.0, 20.0);
    // One joined SoftCard (radius 20, v4 padding) — same chrome as the live
    // joined lists (F166), not the legacy CardColumn card/margin/28-8 radii.
    return _ClipSafe(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        borderRadius: 20,
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: (height * 0.3).clamp(10.0, 22.0),
              ),
              child: Row(
                children: [
                  _Bone(width: barHeight + 8, height: barHeight + 8, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(child: _Bone(width: double.infinity, height: barHeight)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expense-list ledger skeleton (F166): mirrors the real day-grouped ledger —
/// a short [SectionLabel]-height day header bar, then a [SoftCard] holding a few
/// `_QuickRow` silhouettes (42px rounded icon tile + title/subtitle bars +
/// trailing total bar). Repeated for a couple of day sections.
class _LedgerSkeletonList extends StatelessWidget {
  const _LedgerSkeletonList({required this.count});

  /// Total row count to spread across day sections (mirrors the live ledger's
  /// rows-per-day rhythm rather than one flat card).
  final int count;

  @override
  Widget build(BuildContext context) {
    // Spread rows across day sections of ~4 (matches the live day grouping).
    const rowsPerSection = 4;
    final sectionCount = (count / rowsPerSection).ceil().clamp(1, count);
    var remaining = count;

    final sections = <Widget>[];
    for (var s = 0; s < sectionCount; s++) {
      final rows = remaining < rowsPerSection ? remaining : rowsPerSection;
      remaining -= rows;
      sections.add(_DaySectionSkeleton(rows: rows));
    }

    return _ClipSafe(child: Column(children: sections));
  }
}

/// One day section: a header bar + a joined [SoftCard] of `_QuickRow` bones.
class _DaySectionSkeleton extends StatelessWidget {
  const _DaySectionSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SectionLabel-height day header bar.
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: _Bone(width: 84, height: 12),
          ),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: 20,
            child: Column(
              children: List.generate(rows, (_) => const _QuickRowSkeleton()),
            ),
          ),
        ],
      ),
    );
  }
}

/// One `_QuickRow` silhouette: 42px rounded icon tile, title + net-line bars,
/// trailing total bar (padding v3 all-14 like the real row).
class _QuickRowSkeleton extends StatelessWidget {
  const _QuickRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          _Bone(width: 42, height: 42, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: 130, height: 15),
                SizedBox(height: 6),
                _Bone(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: 10),
          _Bone(width: 58, height: 15),
        ],
      ),
    );
  }
}

/// Wraps a skeleton list so it clips (rather than overflows) when the caller
/// places it in a bounded box (e.g. an `Expanded`) shorter than the skeleton —
/// the original [ShimmerCardList] scrolled via a ListView; the skeletons here
/// are non-scrolling Columns, so this restores that clip-safety.
class _ClipSafe extends StatelessWidget {
  const _ClipSafe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
