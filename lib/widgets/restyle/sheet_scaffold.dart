import 'package:flutter/material.dart';

/// A reusable bottom-sheet scaffold: a warm sheet surface
/// ([ColorScheme.surfaceContainerLow]) with a 28px top radius, a centered drag
/// handle, an optional title row, a scrollable [body], and an optional sticky
/// [footer] slot.
///
/// This is the restyled wrapper for the redesign; it mirrors the drag-handle
/// look of [SliverGrabWidget] but composes as a plain widget rather than a
/// sliver.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleTrailing,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: textTheme.titleLarge),
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
