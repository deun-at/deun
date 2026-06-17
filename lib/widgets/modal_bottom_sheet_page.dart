import 'package:flutter/material.dart';

import 'package:deun/constants.dart';

class ModalBottomSheetPage<T> extends Page<T> {
  final Offset? anchorPoint;
  final WidgetBuilder builder;

  /// Sheets can be dismissed by tapping outside by default, matching the
  /// standard Material pattern. Pass false for sheets with unsaved form
  /// state that must be closed explicitly.
  final bool isDismissible;

  /// Route-level drag-to-dismiss stays opt-in: sheets that embed a
  /// DraggableScrollableSheet handle dragging themselves and the two
  /// gesture handlers conflict.
  final bool enableDrag;

  const ModalBottomSheetPage({
    required this.builder,
    this.anchorPoint,
    this.isDismissible = true,
    this.enableDrag = false,
    super.key,
  });

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
      builder: builder,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: kSheetAnimationStyle,
      anchorPoint: anchorPoint,
      settings: this);
}
