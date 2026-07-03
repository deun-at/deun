import 'package:flutter/material.dart';

import 'card_list_view_builder.dart';
import 'restyle/soft_card.dart';
import 'restyle/spaced_card_list.dart';

/// The skeleton silhouette a [ShimmerCardList] paints while its real content
/// loads. Each shape mirrors the v3 card/row it stands in for so the loading
/// state shares the real layout's rhythm (F145).
enum ShimmerShape {
  /// Group-list card: spaced [SoftCard]s, each a leading rounded icon tile +
  /// title bar, then a footer avatar row + a small balance bar.
  card,

  /// Friend / member / contact / search rows: joined [CardColumn] rows, each an
  /// avatar circle + name/subtitle bars and a trailing balance bar.
  row,

  /// Plain stacked bars (expense list, payment, statistics category rows): a
  /// leading dot + a couple of text bars in a joined card list.
  bars,
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

    Color color = colorScheme.surfaceContainerLowest;
    Color shimmerColor = themeData.colorScheme.surface;

    return LinearGradient(
      colors: [
        color,
        shimmerColor,
        color,
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
/// into one card via [CardColumn].
class _RowSkeletonList extends StatelessWidget {
  const _RowSkeletonList({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Clip-safe inside an Expanded: extra rows clip rather than overflow.
    return _ClipSafe(
      child: CardColumn(
        children: List.generate(
          count,
          (_) => const Padding(
            padding: EdgeInsets.all(16),
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
    );
  }
}

/// Plain stacked-bar skeleton (the original behavior): a leading dot + a text
/// bar per row, joined into one [CardColumn] card.
class _BarsSkeletonList extends StatelessWidget {
  const _BarsSkeletonList({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Keep bars proportional to the caller's requested row height.
    final barHeight = (height * 0.28).clamp(10.0, 20.0);
    return _ClipSafe(
      padded: false,
      child: CardColumn(
        children: List.generate(
          count,
          (_) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
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
    );
  }
}

/// Wraps a skeleton list so it clips (rather than overflows) when the caller
/// places it in a bounded box (e.g. an `Expanded`) shorter than the skeleton —
/// the original [ShimmerCardList] scrolled via a ListView; the skeletons here
/// are non-scrolling Columns, so this restores that clip-safety.
class _ClipSafe extends StatelessWidget {
  const _ClipSafe({required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padded
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      child: child,
    );
  }
}
