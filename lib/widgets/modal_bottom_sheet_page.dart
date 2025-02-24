import 'package:flutter/material.dart';

class ModalBottomSheetPage<T> extends Page<T> {
  final Offset? anchorPoint;
  final WidgetBuilder builder;

  const ModalBottomSheetPage({required this.builder, this.anchorPoint, super.key});

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
      builder: builder,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      anchorPoint: anchorPoint,
      settings: this);
}
