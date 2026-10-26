import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/restyle/primary_button.dart';
import '../../data/expense_deletion_impact.dart';

/// The header's delete button: a spinner while a delete is out, and no taps
/// for as long as it is. A slow probe must not leave it tappable (a repeat tap
/// would stack a second dialog).
class EditorDeleteAction extends StatelessWidget {
  const EditorDeleteAction({
    super.key,
    required this.inFlight,
    required this.onPressed,
  });

  final bool inFlight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: inFlight ? null : onPressed,
      icon: inFlight
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurface,
              ),
            )
          : Icon(Icons.delete_outline, color: colorScheme.onSurface),
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: EdgeInsets.zero,
    );
  }
}

/// The delete confirmation. The dialog only asks: it closes itself and
/// answers, and the write runs after it. Cancel, a barrier tap and a null
/// result all delete nothing.
Future<bool> showEditorDeleteConfirmation(
  BuildContext context, {
  required ExpenseDeletionImpact impact,
  required String currencyCode,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(impact.confirmTitle(l10n)),
        content: Text(impact.confirmMessage(l10n, currencyCode)),
        actions: <Widget>[
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          PrimaryButton(
            compact: true,
            background: colorScheme.error,
            foreground: colorScheme.onError,
            label: l10n.delete,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
