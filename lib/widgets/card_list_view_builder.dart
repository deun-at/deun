import 'package:flutter/material.dart';

class CardListView extends StatelessWidget {
  const CardListView._builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.color,
    this.outerRadius = const Radius.circular(20),
    this.innerRadius = const Radius.circular(5),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final Color? color;
  final Radius outerRadius;
  final Radius innerRadius;

  factory CardListView.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    Color? color,
    Radius outerRadius = const Radius.circular(20),
    Radius innerRadius = const Radius.circular(5),
  }) {
    return CardListView._builder(
      key: key,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      color: color,
      outerRadius: outerRadius,
      innerRadius: innerRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final Radius topRadius = index == 0 ? outerRadius : innerRadius;
        final Radius bottomRadius = index == itemCount - 1 ? outerRadius : innerRadius;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: topRadius, bottom: bottomRadius),
          ),
          elevation: 0,
          color: color,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}
