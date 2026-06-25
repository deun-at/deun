import 'package:flutter/material.dart';

/// A reusable bottom-sheet scaffold: a warm sheet surface
/// ([ColorScheme.surfaceContainerLow]) with a 30px top radius, a centered
/// custom drag handle (38×4, [ColorScheme.outlineVariant], radius 2, ~6px top
/// margin), an optional title row, a scrollable [body], and an optional sticky
/// [footer] slot.
///
/// This is the restyled wrapper for the redesign (COMPONENTS §3). It draws its
/// own handle so the theme's [BottomSheetThemeData.showDragHandle] must be
/// `false` to avoid a double handle.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleTrailing,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 26),
  });

  /// Scrollable sheet content.
  final Widget body;

  /// Optional title shown next to the drag handle.
  final String? title;

  /// Optional trailing action in the title row (e.g. a close button).
  final Widget? titleTrailing;

  /// Optional sticky footer (e.g. a primary CTA) pinned below the body.
  final Widget? footer;

  /// Padding applied around the body (and footer).
  /// Defaults to `EdgeInsets.fromLTRB(20, 8, 20, 26)` per COMPONENTS §3.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom drag handle: 38×4, radius 2, outlineVariant, ~6px top margin.
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ?titleTrailing,
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: padding,
                child: body,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}
