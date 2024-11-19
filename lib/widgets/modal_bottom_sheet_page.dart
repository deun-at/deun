import 'package:flutter/material.dart';

class ModalBottomSheetPage<T> extends Page<T> {
  final Offset? anchorPoint;
  final WidgetBuilder builder;

  const ModalBottomSheetPage(
      {required this.builder,
      this.anchorPoint,
      super.key});

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
      builder: builder,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      anchorPoint: anchorPoint);
}