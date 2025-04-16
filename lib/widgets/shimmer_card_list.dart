import 'package:flutter/material.dart';

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
  const ShimmerCardList({super.key, required this.height, required this.listEntryLength, this.isNegative = false});

  final double height;
  final int listEntryLength;
  final bool isNegative;

  @override
  State<StatefulWidget> createState() => ShimmerCardListState();
}

class ShimmerCardListState extends State<ShimmerCardList> with SingleTickerProviderStateMixin {
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

    Color color;
    Color shimmerColor;

    if (!widget.isNegative) {
      color = themeData.colorScheme.surfaceContainer;
      shimmerColor = themeData.colorScheme.surfaceContainerHighest;
    } else {
      color = themeData.brightness == Brightness.light
          ? themeData.colorScheme.surfaceContainerLowest
          : themeData.colorScheme.surfaceContainerHighest;
      shimmerColor = themeData.colorScheme.surfaceContainer;
    }

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
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                    widget.listEntryLength,
                    (index) => Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                          child: Container(
                            width: double.infinity,
                            height: widget.height,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )),
              ));
        });
  }
}

class ShimmerCardListTile extends StatelessWidget {
  const ShimmerCardListTile({super.key, this.listTileAmount = 1});
  final int listTileAmount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listTileAmount,
      itemBuilder: (context, index) {
        return Padding(
            padding: const EdgeInsets.fromLTRB(5.0, 8.0, 5.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 150, child: ShimmerCardList(height: 15, listEntryLength: 1)),
                SizedBox(width: 250, child: ShimmerCardList(height: 15, listEntryLength: 1)),
              ],
            ));
      },
    );
  }
}
