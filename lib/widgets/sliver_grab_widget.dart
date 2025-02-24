import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SliverGrabWidget extends StatelessWidget {
  const SliverGrabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? const SliverToBoxAdapter(child: SizedBox())
        : SliverPersistentHeader(
            pinned: true, // Keeps it fixed at the top
            floating: true, // Set to true if you want it to appear when scrolling up
            delegate: _SliverAppBarDelegate(
              minHeight: 20,
              maxHeight: 20,
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surface,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    width: 32.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            ));
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight || oldDelegate.maxHeight != maxHeight || oldDelegate.child != child;
  }
}
