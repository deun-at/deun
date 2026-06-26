import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

import 'sheet_scaffold.dart';

/// Shows a warm destructive-confirmation bottom sheet (COMPONENTS §3).
///
/// A reusable confirm sheet for delete-style actions: a centered 54×54 danger
/// badge, a title + message, a danger-filled confirm button and a plain cancel.
/// Resolves to `true` when the user confirms, and `false` (or `null` if
/// dismissed by tapping outside / swiping down) otherwise — so callers can
/// `if (await showDeleteConfirmationSheet(...) == true)`.
Future<bool?> showDeleteConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  IconData icon = Icons.delete_outline,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      final danger = Theme.of(sheetContext).extension<SemanticColors>()!.danger;
      return SheetScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 54×54 warm danger badge (prototype #FBEAE5 ≈ danger @ ~0.14 alpha).
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: danger, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      );
    },
  );
}
