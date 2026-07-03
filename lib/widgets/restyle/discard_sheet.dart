import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'primary_button.dart';
import 'sheet_scaffold.dart';

/// Shows the restyled "Discard changes?" confirmation as a modal bottom sheet.
///
/// Resolves to `true` when the user chooses to discard, and `false` (or `null`
/// if dismissed by tapping outside / swiping down) otherwise.
Future<bool?> showDiscardConfirmationSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return SheetScaffold(
        title: l10n.discardChangesTitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.discardChangesMessage,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: l10n.discardChangesConfirm,
              background: colorScheme.error,
              foreground: colorScheme.onError,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: l10n.discardChangesKeepEditing,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      );
    },
  );
}
