import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/restyle/primary_button.dart';
import '../../provider/expense_editor_controller.dart';

/// Save footer: pinned below the scrollable body on an opaque surface bar.
/// Present in BOTH modes — Quick saves the expense; Itemized shares the items
/// for claiming (F118).
/// Because it is a sibling of the Expanded list (not an overlay), it always
/// reserves its own space, so scroll content is never hidden behind it.
class EditorSaveFooter extends StatelessWidget {
  const EditorSaveFooter({
    super.key,
    required this.status,
    required this.isSingleEntry,
    required this.isEdit,
    required this.onSave,
  });

  final EditorSaveStatus status;
  final bool isSingleEntry;
  final bool isEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: PrimaryButton(
        loading: status == EditorSaveStatus.busy,
        succeeded: status == EditorSaveStatus.done,
        successLabel: l10n.expenseCreateSuccess,
        onPressed: onSave,
        // expense-editor-edit-labels: the CTA is mode-aware in
        // BOTH axes. Quick/Itemized picks the action; new/edit
        // picks the verb — editing must never read "Add expense".
        // Edit reuses the shared `save` key, the same way
        // group_detail_edit.dart's sticky footer does.
        label: isSingleEntry
            ? (isEdit ? l10n.save : l10n.expenseAddButton)
            : (isEdit
                  ? l10n.expenseSaveAndShareForClaimingEdit
                  : l10n.expenseSaveAndShareForClaiming),
      ),
    );
  }
}
