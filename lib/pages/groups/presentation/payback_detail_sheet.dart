import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_deletion_impact.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/widgets/restyle/delete_confirm_sheet.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

import '../data/group_model.dart';
import 'group_ledger.dart';

/// The write [PaybackDetailSheet] performs. Null in production →
/// [ExpenseRepository.delete]; widget tests inject a stub so they never reach
/// the network (same seam as `RecordPaybackSheet.recordPayback`).
typedef ExpenseDeleter =
    Future<void> Function(String expenseId, String groupId);

/// Opens the detail sheet for one payback row.
///
/// Resolves when the sheet closes and carries no result: the deleted row leaves
/// the ledger through the existing realtime path (`ExpenseRepository.delete`
/// removes the `expense_update_checker` row, which `ExpenseListNotifier`
/// listens to), and `update_group_member_shares` bumps `group_update_checker`
/// for the balance — the caller has nothing to do with the answer.
Future<void> showPaybackDetailSheet(
  BuildContext context, {
  required Group group,
  required Expense expense,
  ExpenseDeleter? deleteExpense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (_) => ThemeBuilder(
      colorValue: group.colorValue,
      builder: (_) => PaybackDetailSheet(
        group: group,
        expense: expense,
        deleteExpense: deleteExpense,
      ),
    ),
  );
}

/// The read/undo surface for one payback (settle-up) row.
///
/// A payback's `name` is the literal string `'paid_back'`, and the ordinary
/// expense read view's header carries an Edit action that pushes the full
/// expense editor onto a synthetic single-entry row it was never designed to
/// save — so this is a dedicated sheet, mirroring `RecordPaybackSheet`, the
/// surface that *writes* the row this one undoes.
class PaybackDetailSheet extends StatefulWidget {
  const PaybackDetailSheet({
    super.key,
    required this.group,
    required this.expense,
    this.deleteExpense,
  });

  final Group group;
  final Expense expense;
  final ExpenseDeleter? deleteExpense;

  @override
  State<PaybackDetailSheet> createState() => _PaybackDetailSheetState();
}

class _PaybackDetailSheetState extends State<PaybackDetailSheet> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    if (_deleting) return;
    final l10n = AppLocalizations.of(context)!;

    // The SAME classifier every other delete in the app runs through. A
    // payback row short-circuits the probe inside probeDeletionImpact, so
    // this costs no network round-trip and needs no loader seam.
    final impact = await probeDeletionImpact(widget.expense);
    if (!mounted) return;

    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: impact.confirmTitle(l10n),
      message: impact.confirmMessage(l10n, widget.group.currencyCode),
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await (widget.deleteExpense ?? ExpenseRepository.delete)(
        widget.expense.id,
        widget.expense.groupId,
      );
    } catch (e) {
      debugPrint('Failed to delete payback ${widget.expense.id}: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      showSnackBar(context, l10n.expenseDeleteError);
      return;
    }
    if (!mounted) return;
    // Snackbar BEFORE the pop on purpose: the messenger is an ancestor of
    // this sheet's route, so the confirmation outlives the sheet and lands on
    // the ledger the row just left. A delete keeps its snackbar —
    // save-status-rollout ruled deletes out of the on-CTA confirmation,
    // because no CTA survives the confirmation sheet.
    showSnackBar(context, l10n.expenseDeleteSuccess);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final danger = Theme.of(context).extension<SemanticColors>()!.danger;

    return SheetScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            paybackSummaryLine(
              widget.expense,
              l10n,
              currencyCode: widget.group.currencyCode,
              currentUserEmail: supabase.auth.currentUser?.email,
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            formatDate(widget.expense.expenseDate, context),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          // payback-on-behalf: the row says who recorded it, and so does this
          // sheet — the person about to undo it should see the same
          // attribution.
          if (widget.expense.isRecordedOnBehalf) ...[
            const SizedBox(height: 6),
            Text(
              l10n.paybackRecordedBy(
                widget.expense.recordedByDisplayName ?? '',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      footer: PrimaryButton(
        key: const ValueKey('payback_detail_delete'),
        label: l10n.delete,
        background: danger,
        foreground: colorScheme.onError,
        loading: _deleting,
        onPressed: _deleting ? null : _confirmDelete,
      ),
    );
  }
}
