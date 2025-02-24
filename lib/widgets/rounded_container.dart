import 'package:flutter/material.dart';

class RoundedContainer extends Container {
  RoundedContainer({
    super.key,
    super.child,
    super.width,
    super.height,
    super.margin,
    super.padding,
    super.alignment,
  }) : super(
          decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          clipBehavior: Clip.antiAlias,
        );
}
