import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/material.dart';

class GroupCardListView extends CardListView {
  const GroupCardListView({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    required this.groupList,
    super.shrinkWrap,
    super.physics,
    super.adBlock,
    super.addSpacer,
    super.controller,
  });

  final List<Group> groupList;

  @override
  Widget _itemBuilder(BuildContext context, int index, int finalItemCount, Color? color) {
    Group group = groupList[index];
    ThemeData themeData = Theme.of(context);
    Color colorSeedValue = Color(group.colorValue);

    return Theme(
      data: themeData.copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: colorSeedValue, brightness: themeData.brightness)),
      child: Builder(builder: (context) {
        ThemeData themeData = Theme.of(context);
        ColorScheme colorScheme = themeData.colorScheme;

        Color cardColor = themeData.brightness == Brightness.light
            ? colorScheme.primary
            : colorScheme.primaryContainer;

        return super._itemBuilder(context, index, finalItemCount, cardColor);
      }),
    );
  }
}

class CardListView extends StatelessWidget {
  const CardListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.color,
    this.shrinkWrap,
    this.physics,
    this.adBlock,
    this.addSpacer,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final Color? color;
  final Radius outerRadius = const Radius.circular(28);
  final Radius innerRadius = const Radius.circular(8);
  final bool? shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? adBlock;
  final int adPosition = 10;
  final bool? addSpacer;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    int finalItemCount = itemCount;
    int spacerItemCount = finalItemCount;

    if (addSpacer == true) {
      spacerItemCount++;
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap ?? false,
      physics: physics,
      itemCount: spacerItemCount,
      itemBuilder: (context, index) {
        if (addSpacer == true && index == spacerItemCount - 1) {
          return SizedBox(height: 80);
        }

        return _itemBuilder(context, index, finalItemCount, color);
      },
    );
  }

  Widget _itemBuilder(BuildContext context, int index, int finalItemCount, Color? color) {
    bool isTop = index == 0;
    bool isBottom = index == finalItemCount - 1;

    bool adIsTop = false;
    bool adIsBottom = false;

    if (adBlock != null && finalItemCount <= adPosition) {
      isBottom = false;
      adIsBottom = true;
    }

    Widget card = CardListTile(
      isTop: isTop,
      isBottom: isBottom,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      child: itemBuilder(context, index),
    );

    if (adBlock != null &&
        (index == adPosition - 1 ||
            (finalItemCount < adPosition && index == finalItemCount - 1))) {
      return Column(children: [
        card,
        CardListTile(isTop: adIsTop, isBottom: adIsBottom, child: adBlock!)
      ]);
    } else {
      return card;
    }
  }
}

class CardListTile extends StatelessWidget {
  const CardListTile(
      {super.key, required this.child, this.color, this.isTop, this.isBottom});

  final Widget child;
  final Color? color;
  final bool? isTop;
  final bool? isBottom;

  @override
  Widget build(BuildContext context) {
    final Radius big = Radius.circular(28);
    final Radius small = Radius.circular(8);

    Radius top = small;
    Radius bottom = small;

    if (isTop == true) {
      top = big;
    }

    if (isBottom == true) {
      bottom = big;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: top, bottom: bottom),
      ),
      elevation: 0,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      child: child,
    );
  }
}

class CardColumn extends StatelessWidget {
  const CardColumn({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    int childrenLength = children.length;
    int index = 0;

    return Column(
      children: children.map((child) {
        bool isTop = false;
        bool isBottom = false;
        if (index == 0) {
          isTop = true;
        }

        if (index == childrenLength - 1) {
          isBottom = true;
        }

        index++;

        return CardListTile(isTop: isTop, isBottom: isBottom, color: color, child: child);
      }).toList(),
    );
  }
}
